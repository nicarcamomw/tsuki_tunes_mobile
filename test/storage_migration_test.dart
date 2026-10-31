import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';

Map<String, dynamic> _song(String id) => {
      'trackId': id,
      'title': 'Song $id',
      'artistName': 'Artist',
      'albumTitle': 'Album',
      'albumId': 'alb',
      'coverUrl': '',
      'previewUrl': '',
      'duration': 100,
      'listenedAt': DateTime(2026, 1, int.parse(id)).toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const legacyKey = 'tsuki_cached_tracks_u1';

  late AppDatabase db;
  late StorageService storage;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = StorageService(localStore: LibraryStore(db));
  });
  tearDown(() => db.close());

  test('the old JSON library moves into the database once, then is deleted', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: jsonEncode([_song('1'), _song('2')]),
    });

    final first = await storage.getCachedListenedTracks('u1');
    expect(first.map((t) => t['trackId']), ['2', '1']);
    expect((await db.select(db.listenedTracks).get()).length, 2);
    expect((await SharedPreferences.getInstance()).getString(legacyKey), isNull);

    // Next launch: straight from the database.
    final again = await StorageService(localStore: LibraryStore(db)).getCachedListenedTracks('u1');
    expect(again.map((t) => t['trackId']), ['2', '1']);
  });

  test('new saves go to the database, not to SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    await storage.saveCachedListenedTracks('u1', [_song('3')]);

    expect((await SharedPreferences.getInstance()).getString(legacyKey), isNull);
    expect((await db.select(db.listenedTracks).get()).single.trackId, '3');
  });

  test('a failed database write keeps the old library', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: jsonEncode([_song('1')]),
    });
    final failing = StorageService(localStore: _FailingStore(db));

    final tracks = await failing.getCachedListenedTracks('u1');
    expect(tracks.single['trackId'], '1');
    expect((await SharedPreferences.getInstance()).getString(legacyKey), isNotNull);
  });

  test('without the database (web) the library stays where it was', () async {
    SharedPreferences.setMockInitialValues({});
    final plain = StorageService();
    await plain.saveCachedListenedTracks('u1', [_song('4')]);
    expect((await plain.getCachedListenedTracks('u1')).single['trackId'], '4');
    expect((await SharedPreferences.getInstance()).getString(legacyKey), isNotNull);
  });
}

/// A database whose writes fail (a full disk, say).
class _FailingStore extends LibraryStore {
  _FailingStore(super.db);

  @override
  Future<void> saveListened(String uid, List<Map<String, dynamic>> tracks) =>
      Future.error(StateError('disk full'));
}
