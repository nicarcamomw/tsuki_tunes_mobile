import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';

Track createTestTrack(String id) {
  return Track(
    id: id,
    title: 'Track $id',
    artistId: 'artist_$id',
    artistName: 'Artist $id',
    albumId: 'album_$id',
    albumTitle: 'Album $id',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: '', // empty preview to prevent actual network calls in unit tests
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

  group('Fix 1: Previous in Shuffle Mode & Play History Tests', () {
    late AudioProvider provider;
    late List<Track> tracks;

    setUp(() {
      provider = AudioProvider();
      tracks = List.generate(10, (i) => createTestTrack('track_$i'));
      provider.playTrack(tracks[0], newQueue: tracks);
    });

    test('next() records current index in playHistory', () async {
      provider.toggleShuffle();
      expect(provider.isShuffle, isTrue);
      expect(provider.playHistory.isEmpty, isTrue);

      final firstIndex = provider.currentIndex;
      await provider.next();

      expect(provider.playHistory, contains(firstIndex));
      expect(provider.playHistory.length, equals(1));
    });

    test('previous() in shuffle pops from playHistory and returns to actually heard track', () async {
      provider.toggleShuffle();
      expect(provider.isShuffle, isTrue);

      final track0Idx = provider.currentIndex; // 0
      await provider.next();
      final track1Idx = provider.currentIndex;
      await provider.next();
      final track2Idx = provider.currentIndex;

      expect(track2Idx, isNot(equals(track1Idx)));
      expect(provider.playHistory, equals([track0Idx, track1Idx]));

      // Calling previous() should pop track1Idx and play it
      await provider.previous();
      expect(provider.currentIndex, equals(track1Idx));
      expect(provider.playHistory, equals([track0Idx]));

      // Calling previous() again should pop track0Idx and play it
      await provider.previous();
      expect(provider.currentIndex, equals(track0Idx));
      expect(provider.playHistory.isEmpty, isTrue);
    });

    test('previous() rewinds to 0 when position > 3 seconds without consuming history', () async {
      provider.toggleShuffle();
      await provider.next();
      final currentIdx = provider.currentIndex;
      final historyBefore = List<int>.from(provider.playHistory);

      // Simulate playing past 3 seconds
      provider.setPositionForTesting(const Duration(seconds: 10));
      await provider.previous();

      // Should rewind position to 0 and remain on same track, keeping history intact
      expect(provider.currentIndex, equals(currentIdx));
      expect(provider.position, equals(Duration.zero));
      expect(provider.playHistory, equals(historyBefore));
    });

    test('playHistory is bounded to 50 entries', () async {
      for (var i = 0; i < 60; i++) {
        await provider.next();
      }
      expect(provider.playHistory.length, equals(50));
    });

    test('playHistory is cleared on stop, clearQueue, reorderQueue, removeFromQueue, and newQueue', () async {
      provider.toggleShuffle();
      await provider.next();
      expect(provider.playHistory.isNotEmpty, isTrue);

      // 1. stop()
      await provider.stop();
      expect(provider.playHistory.isEmpty, isTrue);

      // Re-populate
      await provider.playTrack(tracks[0], newQueue: tracks);
      await provider.next();
      expect(provider.playHistory.isNotEmpty, isTrue);

      // 2. clearQueue()
      provider.clearQueue();
      expect(provider.playHistory.isEmpty, isTrue);

      // Re-populate
      await provider.playTrack(tracks[0], newQueue: tracks);
      await provider.next();
      expect(provider.playHistory.isNotEmpty, isTrue);

      // 3. reorderQueue()
      provider.reorderQueue(1, 2);
      expect(provider.playHistory.isEmpty, isTrue);

      // Re-populate
      await provider.next();
      expect(provider.playHistory.isNotEmpty, isTrue);

      // 4. removeFromQueue()
      provider.removeFromQueue(5);
      expect(provider.playHistory.isEmpty, isTrue);

      // 5. playTrack with newQueue
      await provider.next();
      expect(provider.playHistory.isNotEmpty, isTrue);
      await provider.playTrack(tracks[1], newQueue: [tracks[1], tracks[2]]);
      expect(provider.playHistory.isEmpty, isTrue);
    });
  });

  group('Fix 2: Wall-Clock Sleep Timer & Lifecycle Tests', () {
    late AudioProvider provider;

    setUp(() {
      provider = AudioProvider();
      final tracks = [createTestTrack('1'), createTestTrack('2')];
      provider.playTrack(tracks[0], newQueue: tracks);
    });

    tearDown(() {
      provider.setSleepTimer(null);
    });

    test('setSleepTimer sets wall-clock deadline and calculates remaining time accurately', () {
      provider.setSleepTimer(const Duration(minutes: 10));

      expect(provider.sleepTimerDeadline, isNotNull);
      expect(provider.isSleepTimerActive, isTrue);

      final diff = provider.sleepTimerDeadline!.difference(DateTime.now());
      expect(diff.inMinutes, inInclusiveRange(9, 10));

      final remaining = provider.sleepTimerRemaining;
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, inInclusiveRange(9, 10));
    });

    test('checkSleepTimer stops playback immediately when deadline expired in background', () async {
      provider.setSleepTimer(const Duration(minutes: 5));
      expect(provider.isSleepTimerActive, isTrue);

      // Simulate time passing in background: set deadline to 1 second in the past
      provider.setSleepTimerDeadlineForTesting(DateTime.now().subtract(const Duration(seconds: 1)));

      // App returns to foreground (lifecycle resume)
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Should stop playback and clear sleep timer
      expect(provider.sleepTimerDeadline, isNull);
      expect(provider.sleepTimerRemaining, isNull);
      expect(provider.isPlaying, isFalse);
    });

    test('checkSleepTimer updates remaining time when deadline is still in future', () {
      provider.setSleepTimer(const Duration(minutes: 30));

      // Simulate advancing time: set deadline to 5 minutes from now
      provider.setSleepTimerDeadlineForTesting(DateTime.now().add(const Duration(minutes: 5)));

      provider.checkSleepTimer();

      expect(provider.isSleepTimerActive, isTrue);
      expect(provider.sleepTimerRemaining!.inMinutes, inInclusiveRange(4, 5));
    });
  });

  group('Fix 3: Loop + Crossfade Inconsistency Tests', () {
    late AudioProvider provider;

    setUp(() async {
      provider = AudioProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await provider.setCrossfadeSeconds(5);
      final tracks = [createTestTrack('t1'), createTestTrack('t2')];
      provider.playTrack(tracks[0], newQueue: tracks);
    });

    test('Loop mode blocks crossfade trigger completely', () {
      provider.toggleLoop();
      expect(provider.isLoop, isTrue);

      // Remaining duration = 180s - 177s = 3s <= 5s crossfade threshold
      provider.checkCrossfade(const Duration(seconds: 177));

      // In loop mode, crossfade must NOT be triggered
      expect(provider.crossfadeTriggered, isFalse);
    });

    test('Non-loop mode allows crossfade trigger', () {
      expect(provider.isLoop, isFalse);
      expect(provider.crossfadeSeconds, equals(5));

      // Remaining duration = 180s - 177s = 3s <= 5s crossfade threshold
      provider.checkCrossfade(const Duration(seconds: 177));

      // Crossfade was triggered
      expect(provider.crossfadeTriggered, isTrue);
    });
  });
}
