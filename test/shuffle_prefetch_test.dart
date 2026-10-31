import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

Track createDummyTrack(String id, String artistId) {
  return Track(
    id: id,
    title: 'Track $id',
    artistId: artistId,
    artistName: 'Artist $artistId',
    albumId: 'album_$artistId',
    albumTitle: 'Album $artistId',
    coverUrl: 'https://example.com/$id.jpg',
    previewUrl: '', // empty preview to prevent actual audio precache http calls
    durationSeconds: 30,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        return {};
      },
    );
  });

  group('Shuffle and Prefetch Synchronization Tests', () {
    test('peekNextIndex returns next sequential index when shuffle is off', () {
      final provider = AudioProvider();
      final tracks = [
        createDummyTrack('1', 'a1'),
        createDummyTrack('2', 'a2'),
        createDummyTrack('3', 'a3'),
      ];

      // Set queue manually without calling native audio platform play
      provider.playTrack(tracks[0], newQueue: tracks);

      expect(provider.isShuffle, isFalse);
      expect(provider.currentIndex, equals(0));
      expect(provider.peekNextIndex(), equals(1));
    });

    test('peekNextIndex memoizes next track when shuffle is on', () {
      final provider = AudioProvider();
      final tracks = [
        createDummyTrack('1', 'a1'),
        createDummyTrack('2', 'a2'),
        createDummyTrack('3', 'a3'),
        createDummyTrack('4', 'a4'),
      ];

      provider.playTrack(tracks[0], newQueue: tracks);
      provider.toggleShuffle();

      expect(provider.isShuffle, isTrue);

      final firstPeek = provider.peekNextIndex();
      expect(firstPeek, isNotNull);
      expect(firstPeek, isNot(equals(0))); // must not be current track
      expect(provider.nextShuffleIndex, equals(firstPeek));

      // Repeated calls must return the exact same memoized index (idempotent)
      final secondPeek = provider.peekNextIndex();
      expect(secondPeek, equals(firstPeek));
      expect(provider.nextShuffleIndex, equals(firstPeek));
    });

    test('toggleShuffle resets memoized shuffle index', () {
      final provider = AudioProvider();
      final tracks = [
        createDummyTrack('1', 'a1'),
        createDummyTrack('2', 'a2'),
        createDummyTrack('3', 'a3'),
      ];

      provider.playTrack(tracks[0], newQueue: tracks);
      provider.toggleShuffle(); // Turn on shuffle

      final shufflePeek = provider.peekNextIndex();
      expect(provider.nextShuffleIndex, equals(shufflePeek));

      provider.toggleShuffle(); // Turn off shuffle
      expect(provider.isShuffle, isFalse);
      expect(provider.nextShuffleIndex, isNull);
      expect(provider.peekNextIndex(), equals(1));
    });

    test('next() consumes the memoized shuffle index that was prefetched', () async {
      final provider = AudioProvider();
      final tracks = [
        createDummyTrack('1', 'a1'),
        createDummyTrack('2', 'a2'),
        createDummyTrack('3', 'a3'),
        createDummyTrack('4', 'a4'),
      ];

      await provider.playTrack(tracks[0], newQueue: tracks);
      provider.toggleShuffle();

      final expectedNext = provider.peekNextIndex();
      expect(expectedNext, isNotNull);
      expect(provider.nextShuffleIndex, equals(expectedNext));

      await provider.next();

      expect(provider.currentIndex, equals(expectedNext));
      expect(provider.currentTrack?.id, equals(tracks[expectedNext!].id));
    });
  });
}

