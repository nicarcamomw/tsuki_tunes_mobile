import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/providers/playlist_provider.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

Map<String, dynamic> _t(String id) => {'id': id, 'title': 'Track $id'};
List<String> _ids(List<Map<String, dynamic>> tracks) =>
    tracks.map((t) => t['id'] as String).toList();

ListenedTrackData _listened(String id, DateTime? at) => ListenedTrackData(
      trackId: id,
      title: 't$id',
      artistName: 'A',
      albumTitle: 'Al',
      albumId: 'alb',
      coverUrl: '',
      duration: 100,
      listenedAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistProvider.mergePlaylistTracks', () {
    test('add keeps tracks added on another device', () {
      final server = [_t('1'), _t('2'), _t('remote')];
      final merged =
          PlaylistProvider.mergePlaylistTracks(server, add: _t('3'));
      expect(_ids(merged), ['1', '2', 'remote', '3']);
    });

    test('add is a no-op when the track is already there', () {
      final merged = PlaylistProvider.mergePlaylistTracks([_t('1')],
          add: {'id': '1', 'title': 'different map'});
      expect(merged.length, 1);
    });

    test('remove only drops that track', () {
      final server = [_t('1'), _t('2'), _t('remote')];
      final merged =
          PlaylistProvider.mergePlaylistTracks(server, removeId: '2');
      expect(_ids(merged), ['1', 'remote']);
    });

    test('reorder applies local order and keeps unknown tracks at the end',
        () {
      final server = [_t('1'), _t('2'), _t('3'), _t('remote')];
      final merged = PlaylistProvider.mergePlaylistTracks(server,
          order: ['3', '1', '2', 'removed-elsewhere']);
      expect(_ids(merged), ['3', '1', '2', 'remote']);
    });
  });

  group('LibraryProvider.applyRemoteDeletion', () {
    test('removes a track listened before the deletion', () async {
      final library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      final deletedAt = DateTime(2026, 10, 20);
      library.setListenedTracksForTesting([
        _listened('old', DateTime(2026, 10, 1)),
        _listened('nodate', null),
      ]);

      expect(library.applyRemoteDeletion('old', deletedAt), isTrue);
      expect(library.applyRemoteDeletion('nodate', deletedAt), isTrue);
      expect(library.isTrackListened('old'), isFalse);
      expect(library.isTrackListened('nodate'), isFalse);
    });

    test('keeps a track re-marked after the deletion', () async {
      final library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      library.setListenedTracksForTesting([
        _listened('remarked', DateTime(2026, 10, 21)),
      ]);

      expect(
          library.applyRemoteDeletion('remarked', DateTime(2026, 10, 20)),
          isFalse);
      expect(library.isTrackListened('remarked'), isTrue);
    });

    test('ignores tracks that are not listened', () async {
      final library = LibraryProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(library.applyRemoteDeletion('missing', DateTime.now()), isFalse);
    });
  });

  group('StorageService last full sync', () {
    test('round-trips per user', () async {
      final storage = StorageService();
      expect(await storage.getLastListenedFullSync('u1'), isNull);
      final t = DateTime(2026, 10, 22, 12);
      await storage.saveLastListenedFullSync('u1', t);
      expect(await storage.getLastListenedFullSync('u1'), t);
      expect(await storage.getLastListenedFullSync('u2'), isNull);
    });
  });
}
