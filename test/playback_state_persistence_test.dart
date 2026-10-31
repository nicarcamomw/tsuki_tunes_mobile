import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/song_radio.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track createTestTrack(String id, {int duration = 180}) {
  return Track(
    id: id,
    title: 'Track $id',
    artistId: 'artist_$id',
    artistName: 'Artist $id',
    albumId: 'album_$id',
    albumTitle: 'Album $id',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: '', // empty preview to prevent actual network calls in unit tests
    durationSeconds: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

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

  group('StorageService Playback State Persistence Tests', () {
    test('savePlaybackState saves and getPlaybackState retrieves valid state', () async {
      final storage = StorageService();
      final tracks = [createTestTrack('t1'), createTestTrack('t2')];

      await storage.savePlaybackState(tracks, 1, 45000);

      final retrieved = await storage.getPlaybackState();
      expect(retrieved, isNotNull);
      expect(retrieved!['currentIndex'], equals(1));
      expect(retrieved['position'], equals(45000));

      final retrievedQueue = (retrieved['queue'] as List)
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      expect(retrievedQueue.length, equals(2));
      expect(retrievedQueue[0].id, equals('t1'));
      expect(retrievedQueue[1].id, equals('t2'));
    });

    test('savePlaybackState(null) removes saved state', () async {
      final storage = StorageService();
      await storage.savePlaybackState([createTestTrack('t1')], 0, 10000);
      expect(await storage.getPlaybackState(), isNotNull);

      await storage.savePlaybackState(null);
      expect(await storage.getPlaybackState(), isNull);
    });
  });

  group('AudioProvider Playback State Persistence & Restoration Tests', () {
    test('AudioProvider restores queue, currentTrack, and position on startup without auto-playing', () async {
      final storage = StorageService();
      final tracks = [createTestTrack('t1'), createTestTrack('t2'), createTestTrack('t3')];

      // Pre-seed storage with a saved playback state
      await storage.savePlaybackState(tracks, 1, 60000);

      // Construct a new AudioProvider (simulates app startup)
      final provider = AudioProvider(storage: storage);

      // Await restoration
      await provider.restorePlaybackStateForTesting();

      expect(provider.queue.length, equals(3));
      expect(provider.currentIndex, equals(1));
      expect(provider.currentTrack?.id, equals('t2'));
      expect(provider.position, equals(const Duration(milliseconds: 60000)));
      expect(provider.duration, equals(const Duration(seconds: 180)));

      // Crucial: Must NOT auto-play
      expect(provider.isPlaying, isFalse);
      expect(provider.isBuffering, isFalse);
    });

    test('AudioProvider restores an active song radio after restart', () async {
      final storage = StorageService();
      final seed = createTestTrack('seed');
      final picked = createTestTrack('p1').copyWith(previewUrl: 'https://cdn/p1.mp3');
      final radio = SongRadio(
        seed: seed,
        mode: RadioMode.familiar,
        similar: (_, __) async => [],
        artistRadio: (_) async => [picked],
        search: (_) async => [],
        useLastFm: false,
      );
      final batch = await radio.nextBatch(count: 4);
      final queue = [seed, ...batch];

      await storage.savePlaybackState(
        queue,
        0,
        5000,
        false,
        radio.toJson(keepReasonsFor: queue.map((t) => t.id)),
      );

      final provider = AudioProvider(storage: storage);
      await provider.restorePlaybackStateForTesting();

      expect(provider.isRadioActive, isTrue);
      expect(provider.radioSeed?.id, 'seed');
      expect(provider.radioMode, RadioMode.familiar);
      expect(provider.radioReasonFor('p1')?.source, RadioSource.deezer);
      expect(provider.isPlaying, isFalse);

      // Saving again keeps the radio in the snapshot.
      provider.persistPlaybackStateNowForTesting();
      final saved = await storage.getPlaybackState();
      expect(saved?['radio'], isA<Map>());

      provider.stopRadio();
      provider.persistPlaybackStateNowForTesting();
      expect((await storage.getPlaybackState())?['radio'], isNull);
    });

    test('stop() clears persisted playback state in storage', () async {
      final storage = StorageService();
      final tracks = [createTestTrack('t1'), createTestTrack('t2')];

      final provider = AudioProvider(storage: storage);
      await provider.playTrack(tracks[0], newQueue: tracks);

      // Force persist
      provider.persistPlaybackStateNowForTesting();
      expect(await storage.getPlaybackState(), isNotNull);

      // Calling stop() should immediately delete the saved state
      await provider.stop();

      final stateAfterStop = await storage.getPlaybackState();
      expect(stateAfterStop, isNull);
    });

    test('queue changes update persisted playback state', () async {
      final storage = StorageService();
      final tracks = [createTestTrack('t1'), createTestTrack('t2'), createTestTrack('t3')];

      final provider = AudioProvider(storage: storage);
      await provider.playTrack(tracks[0], newQueue: tracks);

      // Reorder
      provider.reorderQueue(0, 2);
      provider.persistPlaybackStateNowForTesting();

      var saved = await storage.getPlaybackState();
      expect(saved, isNotNull);
      var savedQueue = (saved!['queue'] as List);
      expect(savedQueue[2]['id'], equals('t1'));

      // Remove from queue
      provider.removeFromQueue(1);
      provider.persistPlaybackStateNowForTesting();

      saved = await storage.getPlaybackState();
      expect(saved, isNotNull);
      savedQueue = (saved!['queue'] as List);
      expect(savedQueue.length, equals(2));

      // Clear queue
      provider.clearQueue();
      provider.persistPlaybackStateNowForTesting();

      saved = await storage.getPlaybackState();
      expect(saved, isNotNull);
      savedQueue = (saved!['queue'] as List);
      expect(savedQueue.length, equals(1));
      expect(savedQueue[0]['id'], equals('t1'));
    });
  });
}
