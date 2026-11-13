import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

class FakeAudioPlayerService extends AudioPlayerService {
  Track? lastPlayedTrack;
  int playCallCount = 0;

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    lastPlayedTrack = track;
    playCallCount++;
  }
}

Track createTestTrack(String id) {
  return Track(
    id: id,
    title: 'Track $id',
    artistId: 'artist_$id',
    artistName: 'Artist $id',
    albumId: 'album_$id',
    albumTitle: 'Album $id',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: 'https://example.com/preview_$id.mp3',
    durationSeconds: 180,
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
          final id = (methodCall.arguments as Map)['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (MethodCall call) async => {},
          );
        }
        return {};
      },
    );
  });

  group('Repeat Mode Tests (Off, All/Queue, One/Track)', () {
    late AudioProvider provider;
    late FakeAudioPlayerService fakePlayer;

    setUp(() {
      fakePlayer = FakeAudioPlayerService();
      provider = AudioProvider(
        service: fakePlayer,
        storage: StorageService(),
      );
    });

    test('toggleRepeat cycles cleanly: off -> all -> one -> off', () {
      expect(provider.repeatMode, equals(PlaybackRepeatMode.off));
      expect(provider.isLoop, isFalse);
      expect(provider.isRepeatAll, isFalse);
      expect(provider.isRepeatOne, isFalse);

      // 1. Off -> All (Repeat queue)
      provider.toggleRepeat();
      expect(provider.repeatMode, equals(PlaybackRepeatMode.all));
      expect(provider.isLoop, isTrue);
      expect(provider.isRepeatAll, isTrue);
      expect(provider.isRepeatOne, isFalse);

      // 2. All -> One (Repeat current track)
      provider.toggleRepeat();
      expect(provider.repeatMode, equals(PlaybackRepeatMode.one));
      expect(provider.isLoop, isTrue);
      expect(provider.isRepeatAll, isFalse);
      expect(provider.isRepeatOne, isTrue);

      // 3. One -> Off
      provider.toggleRepeat();
      expect(provider.repeatMode, equals(PlaybackRepeatMode.off));
      expect(provider.isLoop, isFalse);
      expect(provider.isRepeatAll, isFalse);
      expect(provider.isRepeatOne, isFalse);
    });

    test('setRepeatMode assigns modes directly', () {
      provider.setRepeatMode(PlaybackRepeatMode.all);
      expect(provider.repeatMode, equals(PlaybackRepeatMode.all));

      provider.setRepeatMode(PlaybackRepeatMode.one);
      expect(provider.repeatMode, equals(PlaybackRepeatMode.one));

      provider.setRepeatMode(PlaybackRepeatMode.off);
      expect(provider.repeatMode, equals(PlaybackRepeatMode.off));
    });

    test('peekNextIndex reflects repeat modes at end of queue', () async {
      final tracks = [createTestTrack('t0'), createTestTrack('t1'), createTestTrack('t2')];
      await provider.playTrack(tracks[2], newQueue: tracks); // currently at index 2 (last track)

      // PlaybackRepeatMode.off -> no next track at end of queue
      provider.setRepeatMode(PlaybackRepeatMode.off);
      expect(provider.peekNextIndex(), isNull);

      // PlaybackRepeatMode.all -> next track loops back to index 0
      provider.setRepeatMode(PlaybackRepeatMode.all);
      expect(provider.peekNextIndex(), equals(0));

      // PlaybackRepeatMode.one -> repeats current index 2
      provider.setRepeatMode(PlaybackRepeatMode.one);
      expect(provider.peekNextIndex(), equals(2));
    });

    test('PlaybackRepeatMode.all: loops queue back to index 0 on track completion at end of queue', () async {
      final tracks = [createTestTrack('t0'), createTestTrack('t1'), createTestTrack('t2')];
      provider.setRepeatMode(PlaybackRepeatMode.all);

      // Start at last track (index 2)
      await provider.playTrack(tracks[2], newQueue: tracks);
      expect(provider.currentIndex, equals(2));
      expect(provider.currentTrack?.id, equals('t2'));

      // Natural track completion at end of queue
      await provider.handleTrackCompletedForTesting();

      // Wraps around to start of queue (index 0)
      expect(provider.currentIndex, equals(0));
      expect(provider.currentTrack?.id, equals('t0'));
    });

    test('PlaybackRepeatMode.one: replays same track on completion without advancing', () async {
      final tracks = [createTestTrack('t0'), createTestTrack('t1'), createTestTrack('t2')];
      provider.setRepeatMode(PlaybackRepeatMode.one);

      await provider.playTrack(tracks[1], newQueue: tracks);
      expect(provider.currentIndex, equals(1));
      expect(provider.currentTrack?.id, equals('t1'));

      final initialPlayCount = fakePlayer.playCallCount;

      // Natural track completion in repeat-one
      await provider.handleTrackCompletedForTesting();

      // Must remain on index 1 and replay same track
      expect(provider.currentIndex, equals(1));
      expect(provider.currentTrack?.id, equals('t1'));
      expect(fakePlayer.playCallCount, equals(initialPlayCount + 1));
      expect(fakePlayer.lastPlayedTrack?.id, equals('t1'));
    });

    test('PlaybackRepeatMode.off: stops playback on completion of the last track', () async {
      final tracks = [createTestTrack('t0'), createTestTrack('t1')];
      provider.setRepeatMode(PlaybackRepeatMode.off);

      // Start at last track
      await provider.playTrack(tracks[1], newQueue: tracks);
      expect(provider.currentIndex, equals(1));

      // Natural track completion in repeat-off at end of queue
      await provider.handleTrackCompletedForTesting();

      // Stops playback
      expect(provider.isPlaying, isFalse);
      expect(provider.currentTrack, isNull);
    });

    test('PlaybackRepeatMode.off: advances to next track if not at the end of queue', () async {
      final tracks = [createTestTrack('t0'), createTestTrack('t1')];
      provider.setRepeatMode(PlaybackRepeatMode.off);

      // Start at first track
      await provider.playTrack(tracks[0], newQueue: tracks);
      expect(provider.currentIndex, equals(0));

      // Natural track completion
      await provider.handleTrackCompletedForTesting();

      // Advances to next track (index 1)
      expect(provider.currentIndex, equals(1));
      expect(provider.currentTrack?.id, equals('t1'));
    });
  });
}
