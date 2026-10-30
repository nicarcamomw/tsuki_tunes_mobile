import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/services/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/services/audio_precache_service.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

class MockConnectivityProvider extends ChangeNotifier implements ConnectivityProvider {
  bool _online;
  MockConnectivityProvider({bool isOnline = false}) : _online = isOnline;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioPlayerService extends AudioPlayerService {
  Track? lastPlayedTrack;
  int playCallCount = 0;

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    lastPlayedTrack = track;
    playCallCount++;
  }
}

Track createTestTrack(String id, {String? previewUrl, int duration = 180}) {
  return Track(
    id: id,
    title: 'Track $id',
    artistId: 'artist_$id',
    artistName: 'Artist $id',
    albumId: 'album_$id',
    albumTitle: 'Album $id',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: previewUrl ?? 'https://example.com/preview_$id.mp3',
    durationSeconds: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockCachedFile(String trackId) {
    final dir = Directory('${Directory.systemTemp.path}/tsuki_preview_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}/preview_$trackId.mp3');
    file.writeAsBytesSync(List.filled(15000, 1));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioPrecacheService().clearCache();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') {
          final id = methodCall.arguments['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (MethodCall call) async => {},
          );
        }
        return {};
      },
    );
  });

  tearDown(() {
    AudioPrecacheService().clearCache();
  });

  group('Offline Playback Tests', () {
    test('Mock ConnectivityProvider can toggle isOnline', () {
      final connectivity = MockConnectivityProvider(isOnline: false);
      expect(connectivity.isOnline, isFalse);

      connectivity.setOnline(true);
      expect(connectivity.isOnline, isTrue);
    });

    test('Track CON cache local -> reproduce OK', () async {
      final connectivity = MockConnectivityProvider(isOnline: false);
      final fakePlayer = FakeAudioPlayerService();
      final storage = StorageService();
      final audioProvider = AudioProvider(
        service: fakePlayer,
        storage: storage,
        connectivityProvider: connectivity,
      );

      final track = createTestTrack('cached_t1');
      mockCachedFile(track.id);

      expect(AudioPrecacheService().getCachedFilePath(track.id), isNotNull);
      expect(audioProvider.canPlayOfflineForTesting(track), isTrue);

      await audioProvider.playTrack(track);

      expect(audioProvider.lastPlaybackError, isNull);
      expect(audioProvider.currentTrack?.id, equals('cached_t1'));
      expect(fakePlayer.playCallCount, equals(1));
      expect(fakePlayer.lastPlayedTrack?.id, equals('cached_t1'));
    });

    test('Track SIN cache local -> error network_error, no intenta reproducir', () async {
      final connectivity = MockConnectivityProvider(isOnline: false);
      final fakePlayer = FakeAudioPlayerService();
      final storage = StorageService();
      final audioProvider = AudioProvider(
        service: fakePlayer,
        storage: storage,
        connectivityProvider: connectivity,
      );

      final track = createTestTrack('uncached_t2');
      expect(AudioPrecacheService().getCachedFilePath(track.id), isNull);
      expect(audioProvider.canPlayOfflineForTesting(track), isFalse);

      await audioProvider.playTrack(track);

      expect(audioProvider.lastPlaybackError, equals(PlaybackError.network));
      expect(audioProvider.isBuffering, isFalse);
      expect(fakePlayer.playCallCount, equals(0)); // Never attempted playback
    });

    test('next() offline salta tracks sin cache', () async {
      final connectivity = MockConnectivityProvider(isOnline: false);
      final fakePlayer = FakeAudioPlayerService();
      final storage = StorageService();
      final audioProvider = AudioProvider(
        service: fakePlayer,
        storage: storage,
        connectivityProvider: connectivity,
      );

      final t0 = createTestTrack('t0');
      final t1 = createTestTrack('t1');
      final t2 = createTestTrack('t2');

      // Only t0 and t2 have local cache, t1 does NOT
      mockCachedFile(t0.id);
      mockCachedFile(t2.id);

      await audioProvider.playTrack(t0, newQueue: [t0, t1, t2]);
      expect(audioProvider.currentIndex, equals(0));
      expect(audioProvider.currentTrack?.id, equals('t0'));
      expect(fakePlayer.playCallCount, equals(1));

      // Advancing next() should skip uncached t1 and play cached t2
      await audioProvider.next();

      expect(audioProvider.currentIndex, equals(2));
      expect(audioProvider.currentTrack?.id, equals('t2'));
      expect(audioProvider.lastPlaybackError, isNull);
      expect(fakePlayer.playCallCount, equals(2));
      expect(fakePlayer.lastPlayedTrack?.id, equals('t2'));
    });

    test('next() offline stops and reports network_error when no tracks in queue have cache', () async {
      final connectivity = MockConnectivityProvider(isOnline: false);
      final fakePlayer = FakeAudioPlayerService();
      final storage = StorageService();
      final audioProvider = AudioProvider(
        service: fakePlayer,
        storage: storage,
        connectivityProvider: connectivity,
      );

      final t0 = createTestTrack('t0_uncached');
      final t1 = createTestTrack('t1_uncached');

      await audioProvider.playTrack(t0, newQueue: [t0, t1]);
      expect(audioProvider.lastPlaybackError, equals(PlaybackError.network));
      expect(fakePlayer.playCallCount, equals(0));

      // Calling next() when no tracks have cache should not advance and keep network_error
      await audioProvider.next();
      expect(audioProvider.currentIndex, equals(0));
      expect(audioProvider.lastPlaybackError, equals(PlaybackError.network));
      expect(fakePlayer.playCallCount, equals(0));
    });

    test('precarga las 5 canciones siguientes', () async {
      final connectivity = MockConnectivityProvider(isOnline: true);
      final audioProvider = AudioProvider(
        service: FakeAudioPlayerService(),
        storage: StorageService(),
        connectivityProvider: connectivity,
      );
      final queue = [for (var i = 0; i < 8; i++) createTestTrack('q$i')];

      final prefetchedIds = <String>[];
      audioProvider.onPrecacheTrackForTesting = (track) {
        prefetchedIds.add(track.id);
      };

      await audioProvider.playTrack(queue[0], newQueue: queue);

      expect(prefetchedIds.take(5), equals(['q1', 'q2', 'q3', 'q4', 'q5']));
    });

    test('la ventana de precarga avanza con cada canción', () async {
      final connectivity = MockConnectivityProvider(isOnline: true);
      final audioProvider = AudioProvider(
        service: FakeAudioPlayerService(),
        storage: StorageService(),
        connectivityProvider: connectivity,
      );
      final queue = [for (var i = 0; i < 8; i++) createTestTrack('q$i')];
      await audioProvider.playTrack(queue[0], newQueue: queue);

      final prefetchedIds = <String>[];
      audioProvider.onPrecacheTrackForTesting = (track) {
        prefetchedIds.add(track.id);
      };
      await audioProvider.next();

      expect(prefetchedIds.take(5), equals(['q2', 'q3', 'q4', 'q5', 'q6']));
    });

    test('al final de la lista sin repetir no precarga de más', () async {
      final connectivity = MockConnectivityProvider(isOnline: true);
      final audioProvider = AudioProvider(
        service: FakeAudioPlayerService(),
        storage: StorageService(),
        connectivityProvider: connectivity,
      );
      final queue = [for (var i = 0; i < 3; i++) createTestTrack('q$i')];

      final prefetchedIds = <String>[];
      audioProvider.onPrecacheTrackForTesting = (track) {
        prefetchedIds.add(track.id);
      };
      await audioProvider.playTrack(queue[0], newQueue: queue);

      expect(prefetchedIds.toSet(), equals({'q1', 'q2'}));
    });

    test('en aleatorio precarga las canciones que next() tocará', () async {
      final connectivity = MockConnectivityProvider(isOnline: true);
      final audioProvider = AudioProvider(
        service: FakeAudioPlayerService(),
        storage: StorageService(),
        connectivityProvider: connectivity,
      );
      final queue = [for (var i = 0; i < 10; i++) createTestTrack('q$i')];
      await audioProvider.playTrack(queue[0], newQueue: queue);
      audioProvider.toggleShuffle();

      final prefetchedIds = <String>[];
      audioProvider.onPrecacheTrackForTesting = (track) {
        prefetchedIds.add(track.id);
      };
      audioProvider.prefetchUpcomingForTesting();
      final expected = prefetchedIds.take(5).toList();
      expect(expected.length, equals(5));

      final played = <String>[];
      for (var i = 0; i < 5; i++) {
        await audioProvider.next();
        played.add(audioProvider.currentTrack!.id);
      }
      expect(played, equals(expected));
    });

    test('sin conexión sigue con las canciones ya precargadas', () async {
      final connectivity = MockConnectivityProvider(isOnline: false);
      final audioProvider = AudioProvider(
        service: FakeAudioPlayerService(),
        storage: StorageService(),
        connectivityProvider: connectivity,
      );
      for (var i = 0; i < 4; i++) {
        mockCachedFile('c$i');
      }
      final queue = [for (var i = 0; i < 4; i++) createTestTrack('c$i')];
      await audioProvider.playTrack(queue[0], newQueue: queue);

      // Everything is already on disk: playback keeps going offline.
      await audioProvider.next();
      expect(audioProvider.currentTrack?.id, equals('c1'));
      expect(audioProvider.lastPlaybackError, isNull);
    });
  });
}
