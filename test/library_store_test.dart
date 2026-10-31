import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';

Map<String, dynamic> _song(String id, {String title = 'Song', DateTime? at}) => {
      'trackId': id,
      'title': '$title $id',
      'artistName': 'Artist',
      'albumTitle': 'Album',
      'albumId': 'alb',
      'coverUrl': '',
      'previewUrl': '',
      'duration': 100,
      'listenedAt': (at ?? DateTime(2026, 1, 1)).toIso8601String(),
    };

void main() {
  late AppDatabase db;
  late LibraryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LibraryStore(db);
  });
  tearDown(() => db.close());

  group('listened songs', () {
    test('come back as saved, newest first', () async {
      await store.saveListened('u1', [
        _song('a', at: DateTime(2026, 1, 1)),
        _song('b', at: DateTime(2026, 3, 1)),
        _song('c', at: DateTime(2026, 2, 1)),
      ]);
      final loaded = await LibraryStore(db).loadListened('u1');
      expect(loaded.map((t) => t['trackId']), ['b', 'c', 'a']);
      expect(loaded.first, _song('b', at: DateTime(2026, 3, 1)));
    });

    test('a save writes only the songs that changed', () async {
      final songs = [_song('a'), _song('b')];
      await store.saveListened('u1', songs);

      // Edit a row behind the store's back: a save that rewrote every row
      // would put it back.
      await (db.update(db.listenedTracks)..where((t) => t.trackId.equals('a')))
          .write(const ListenedTracksCompanion(title: Value('edited')));

      await store.saveListened('u1', [...songs, _song('c')]);
      final rows = {for (final r in await db.select(db.listenedTracks).get()) r.trackId: r.title};
      expect(rows, {'a': 'edited', 'b': 'Song b', 'c': 'Song c'});
    });

    test('unmarked songs are deleted; accounts stay apart', () async {
      await store.saveListened('u1', [_song('a'), _song('b')]);
      await store.saveListened('u2', [_song('a')]);
      await store.saveListened('u1', [_song('b')]);

      expect((await store.loadListened('u1')).map((t) => t['trackId']), ['b']);
      expect((await store.loadListened('u2')).map((t) => t['trackId']), ['a']);
      expect(await store.hasListened('u3'), isFalse);
      expect(await store.hasListened('u2'), isTrue);
    });

    test('a fresh store finds what is there before saving', () async {
      await store.saveListened('u1', [_song('a'), _song('b')]);
      // As after a restart: the new store hasn't read anything yet.
      await LibraryStore(db).saveListened('u1', [_song('b')]);
      expect((await store.loadListened('u1')).map((t) => t['trackId']), ['b']);
    });
  });

  group('playlists and followed artists', () {
    test('keep their order, update and delete', () async {
      await store.savePlaylists('u1', [
        {'id': 'p1', 'name': 'Noche'},
        {'id': 'p2', 'name': 'Día'},
      ]);
      await store.savePlaylists('u1', [
        {'id': 'p2', 'name': 'Día'},
        {'id': 'p3', 'name': 'Tarde'},
      ]);
      expect((await LibraryStore(db).loadPlaylists('u1')).map((p) => p['id']), ['p2', 'p3']);

      await store.clearPlaylists('u1');
      expect(await store.loadPlaylists('u1'), isEmpty);

      await store.saveFollowed('u1', [
        {'id': '27', 'name': 'SOAD'},
        {'id': '3', 'name': 'Korn'},
      ]);
      expect((await store.loadFollowed('u1')).map((a) => a['name']), ['SOAD', 'Korn']);
    });
  });

  test('the schema is at version 2 (the outbox)', () {
    expect(db.schemaVersion, 2);
  });
}
