import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

List<Track> generateTracks(int count, {String albumId = 'album_1'}) {
  return List.generate(
    count,
    (i) => Track(
      id: 'track_${albumId}_$i',
      title: 'Track $i',
      artistId: 'artist_1',
      artistName: 'Artist 1',
      albumId: albumId,
      albumTitle: 'Album 1',
      coverUrl: 'https://example.com/cover.jpg',
      previewUrl: 'https://example.com/audio_$i.mp3',
      durationSeconds: 180,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Firestore Batch Album Tracks Consistency Tests', () {
    late StorageService storage;
    late LibraryProvider library;
    const testUid = 'user_test_123';

    setUp(() async {
      storage = StorageService();
      library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      library.bypassAuthForTesting = true;
      library.setUidForTesting(testUid);
      library.setListenedTracksLoadedForTesting(true);
    });

    test('markAlbumTracks: partial failure on chunk 2 preserves chunk 1 in local state and cache', () async {
      final tracks = generateTracks(900, albumId: 'album_multi_chunk');
      final chunkCalls = <List<ListenedTrackData>>[];

      // Handler succeeds for chunk 0 (450 tracks) and fails for chunk 1 (450 tracks)
      library.markAlbumChunkHandlerForTesting = (chunk, uid) async {
        chunkCalls.add(chunk);
        if (chunkCalls.length == 2) {
          throw Exception('Simulated Firestore network timeout on chunk 2');
        }
      };

      await library.markAlbumTracks(tracks, albumId: 'album_multi_chunk', totalTracks: 900);

      // Verify 2 chunk attempts were made
      expect(chunkCalls.length, equals(2));
      expect(chunkCalls[0].length, equals(450));
      expect(chunkCalls[1].length, equals(450));

      // Local state should NOT rollback chunk 1 tracks that succeeded in Firestore
      expect(library.listenedTracks.length, equals(450));
      expect(library.listenedTrackIds.length, equals(450));
      expect(library.totalTracksCount, equals(450));

      // Chunk 0 tracks should be marked
      for (var i = 0; i < 450; i++) {
        expect(library.isTrackListened('track_album_multi_chunk_$i'), isTrue);
      }

      // Chunk 1 tracks should NOT be marked (rolled back because Firestore commit failed)
      for (var i = 450; i < 900; i++) {
        expect(library.isTrackListened('track_album_multi_chunk_$i'), isFalse);
      }

      // Verify storage matches local state (450 tracks)
      final cached = await storage.getCachedListenedTracks(testUid);
      expect(cached.length, equals(450));
      expect(cached.first['trackId'], equals('track_album_multi_chunk_0'));
    });

    test('markAlbumTracks: immediate failure on chunk 1 fully rolls back all state', () async {
      final tracks = generateTracks(900, albumId: 'album_fail_first');

      library.markAlbumChunkHandlerForTesting = (chunk, uid) async {
        throw Exception('Simulated Firestore error on chunk 1');
      };

      await library.markAlbumTracks(tracks, albumId: 'album_fail_first', totalTracks: 900);

      expect(library.listenedTracks.isEmpty, isTrue);
      expect(library.listenedTrackIds.isEmpty, isTrue);
      expect(library.totalTracksCount, equals(0));

      final cached = await storage.getCachedListenedTracks(testUid);
      expect(cached.isEmpty, isTrue);
    });

    test('markAlbumTracks: all chunks succeed leaves all 900 tracks marked', () async {
      final tracks = generateTracks(900, albumId: 'album_success');
      var chunksCommitted = 0;

      library.markAlbumChunkHandlerForTesting = (chunk, uid) async {
        chunksCommitted++;
      };

      await library.markAlbumTracks(tracks, albumId: 'album_success', totalTracks: 900);

      expect(chunksCommitted, equals(2));
      expect(library.listenedTracks.length, equals(900));
      expect(library.listenedTrackIds.length, equals(900));
      expect(library.totalTracksCount, equals(900));

      final cached = await storage.getCachedListenedTracks(testUid);
      expect(cached.length, equals(900));
    });

    test('unmarkAlbumTracks: partial failure on chunk 2 keeps chunk 1 deleted and restores chunk 2', () async {
      // Setup 900 listened tracks initially
      final tracks = generateTracks(900, albumId: 'album_unmark_test');
      library.setListenedTracksForTesting(
        tracks
            .map((t) => ListenedTrackData(
                  trackId: t.id,
                  title: t.title,
                  artistName: t.fullArtistName,
                  albumTitle: t.albumTitle,
                  albumId: t.albumId,
                  coverUrl: t.coverUrl,
                  previewUrl: t.previewUrl,
                  duration: t.durationSeconds,
                  listenedAt: DateTime.now(),
                ))
            .toList(),
      );

      expect(library.listenedTracks.length, equals(900));

      final chunkCalls = <List<String>>[];
      // Chunk 1 deletes 450 successfully, Chunk 2 throws
      library.unmarkAlbumChunkHandlerForTesting = (chunkIds, uid) async {
        chunkCalls.add(chunkIds);
        if (chunkCalls.length == 2) {
          throw Exception('Simulated Firestore error on chunk 2 during unmark');
        }
      };

      final allIds = tracks.map((t) => t.id).toList();
      await library.unmarkAlbumTracks(allIds);

      expect(chunkCalls.length, equals(2));
      expect(chunkCalls[0].length, equals(450));
      expect(chunkCalls[1].length, equals(450));

      // Local state:
      // Chunk 0 was successfully deleted in Firestore -> remains deleted locally
      // Chunk 1 failed to delete in Firestore -> restored locally
      expect(library.listenedTracks.length, equals(450));
      expect(library.listenedTrackIds.length, equals(450));
      expect(library.totalTracksCount, equals(450));

      // Chunk 0 tracks should NOT be listened
      for (var i = 0; i < 450; i++) {
        expect(library.isTrackListened('track_album_unmark_test_$i'), isFalse);
      }

      // Chunk 1 tracks SHOULD still be listened
      for (var i = 450; i < 900; i++) {
        expect(library.isTrackListened('track_album_unmark_test_$i'), isTrue);
      }

      final cached = await storage.getCachedListenedTracks(testUid);
      expect(cached.length, equals(450));
      expect(cached.first['trackId'], equals('track_album_unmark_test_450'));
    });

    test('unmarkAlbumTracks: immediate failure on chunk 1 restores all 900 tracks', () async {
      final tracks = generateTracks(900, albumId: 'album_unmark_fail');
      library.setListenedTracksForTesting(
        tracks
            .map((t) => ListenedTrackData(
                  trackId: t.id,
                  title: t.title,
                  artistName: t.fullArtistName,
                  albumTitle: t.albumTitle,
                  albumId: t.albumId,
                  coverUrl: t.coverUrl,
                  previewUrl: t.previewUrl,
                  duration: t.durationSeconds,
                  listenedAt: DateTime.now(),
                ))
            .toList(),
      );

      library.unmarkAlbumChunkHandlerForTesting = (chunkIds, uid) async {
        throw Exception('Simulated Firestore error on chunk 1 during unmark');
      };

      final allIds = tracks.map((t) => t.id).toList();
      await library.unmarkAlbumTracks(allIds);

      // All 900 tracks restored
      expect(library.listenedTracks.length, equals(900));
      expect(library.listenedTrackIds.length, equals(900));
      expect(library.totalTracksCount, equals(900));

      final cached = await storage.getCachedListenedTracks(testUid);
      expect(cached.length, equals(900));
    });
  });
}
