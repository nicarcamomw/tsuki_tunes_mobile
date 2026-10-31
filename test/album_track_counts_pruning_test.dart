import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlbumTrackCounts Pruning & Bounded Storage Tests', () {
    test('registerAlbumTrackCount does not persist unlistened albums to storage', () async {
      final storage = StorageService();
      final library = LibraryRepositoryImpl();
      await Future.delayed(const Duration(milliseconds: 50));

      library.setListenedTracksLoadedForTesting(true);

      // Register count for an album that the user has not listened to
      library.registerAlbumTrackCount('album_not_listened', 12);

      // In-memory it is available for current view
      expect(library.getAlbumTracksCount('album_not_listened'), equals(12));

      // Storage should NOT have saved it (remains empty to prevent unbounded accumulation)
      final stored = await storage.getAlbumTrackCounts();
      expect(stored.containsKey('album_not_listened'), isFalse);
    });

    test('pruneAlbumTrackCounts removes orphaned albums and preserves active ones', () async {
      final storage = StorageService();
      final library = LibraryRepositoryImpl();
      await Future.delayed(const Duration(milliseconds: 50));

      // Pre-seed storage with orphaned albums
      await storage.saveAlbumTrackCounts({
        'active_album': 10,
        'orphaned_album_1': 15,
        'orphaned_album_2': 8,
      });

      // Reload into library
      library.registerAlbumTrackCount('active_album', 10);
      library.registerAlbumTrackCount('orphaned_album_1', 15);
      library.registerAlbumTrackCount('orphaned_album_2', 8);

      // Set active listened tracks containing only active_album
      await library.setListenedTracksForTesting([
        ListenedTrackData(
          trackId: 't1',
          title: 'Track 1',
          artistName: 'Artist A',
          albumTitle: 'Active Album',
          albumId: 'active_album',
          coverUrl: '',
          previewUrl: '',
          duration: 30,
        ),
      ]);

      // Prune
      library.pruneAlbumTrackCounts();

      // In-memory: orphaned albums pruned, active preserved
      expect(library.albumTrackCounts.containsKey('active_album'), isTrue);
      expect(library.albumTrackCounts.containsKey('orphaned_album_1'), isFalse);
      expect(library.albumTrackCounts.containsKey('orphaned_album_2'), isFalse);

      // Storage: only active_album persisted
      final storedAfter = await storage.getAlbumTrackCounts();
      expect(storedAfter.containsKey('active_album'), isTrue);
      expect(storedAfter.containsKey('orphaned_album_1'), isFalse);
      expect(storedAfter.containsKey('orphaned_album_2'), isFalse);
    });

    test('pruneAlbumTrackCounts does nothing if listened tracks are not loaded yet', () async {
      final library = LibraryRepositoryImpl();
      await Future.delayed(const Duration(milliseconds: 50));

      library.registerAlbumTrackCount('some_album', 10);
      library.setListenedTracksLoadedForTesting(false);

      // Prune should return early and not wipe albumTrackCounts during startup
      library.pruneAlbumTrackCounts();
      expect(library.albumTrackCounts.containsKey('some_album'), isTrue);
    });

    test('registerAlbumTrackCount persists when album already has listened tracks', () async {
      final storage = StorageService();
      final library = LibraryRepositoryImpl();
      await Future.delayed(const Duration(milliseconds: 50));

      await library.setListenedTracksForTesting([
        ListenedTrackData(
          trackId: 't2',
          title: 'Track 2',
          artistName: 'Artist B',
          albumTitle: 'My Album',
          albumId: 'my_album',
          coverUrl: '',
          previewUrl: '',
          duration: 45,
        ),
      ]);

      library.registerAlbumTrackCount('my_album', 14);

      final stored = await storage.getAlbumTrackCounts();
      expect(stored.containsKey('my_album'), isTrue);
      expect(stored['my_album'], equals(14));
    });
  });
}
