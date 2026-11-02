import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/account_deletion_service.dart';
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
      'listenedAt': DateTime(2026, 1, 1).toIso8601String(),
    };

void main() {
  group('Firestore data of a deleted account', () {
    late FakeFirebaseFirestore db;
    late AccountDeletionService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = AccountDeletionService(db, batchGap: Duration.zero);
      for (final uid in ['me', 'other']) {
        final user = db.collection('users').doc(uid);
        await user.set({
          'displayName': 'Name $uid',
          'email': '$uid@example.com',
          'photoURL': 'https://example.com/$uid.jpg',
          'stats': {'totalTracks': 3},
          'masks': {'equipped': 'oni'},
          'lastSubWrite': DateTime(2026),
        });
        for (var i = 0; i < 450; i++) {
          await user.collection('listenedTracks').doc('t$i').set({'trackId': 't$i'});
        }
        await user.collection('playlists').doc('p1').set({'name': 'Mix'});
        await user.collection('followedArtists').doc('a1').set({'id': 'a1'});
        await user.collection('listenedDeletions').doc('t9').set({'deletedAt': DateTime(2026)});
        await user.collection('playDays').doc('2026-11-02').set({'date': '2026-11-02'});
        await db.collection('profiles').doc(uid).set({'displayName': 'Name $uid'});
      }
    });

    test('everything of the account goes, past one batch', () async {
      await service.deleteUserData('me');

      final user = db.collection('users').doc('me');
      for (final name in [
        'listenedTracks',
        'playlists',
        'followedArtists',
        'listenedDeletions',
        'playDays',
      ]) {
        expect((await user.collection(name).get()).docs, isEmpty, reason: name);
      }
      expect((await db.collection('profiles').doc('me').get()).exists, isFalse);
      // The rules don't let the app delete it: nothing personal stays.
      final left = (await user.get()).data()!;
      expect(left.keys, ['lastSubWrite']);
    });

    test('other accounts are left alone', () async {
      await service.deleteUserData('me');

      final other = db.collection('users').doc('other');
      expect((await other.collection('listenedTracks').get()).docs, hasLength(450));
      expect((await other.get()).data()!['email'], 'other@example.com');
      expect((await db.collection('profiles').doc('other').get()).exists, isTrue);
    });
  });

  group('what the phone keeps for a deleted account', () {
    late AppDatabase db;
    late LibraryStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = LibraryStore(db);
    });
    tearDown(() => db.close());

    test('its library and pending writes go; other accounts stay', () async {
      for (final uid in ['me', 'other']) {
        await store.saveListened(uid, [_song('a'), _song('b')]);
        await store.savePlaylists(uid, [
          {'id': 'p1', 'name': 'Mix', 'tracks': []},
        ]);
        await store.saveFollowed(uid, [
          {'id': 'a1', 'name': 'Artist'},
        ]);
        await db.into(db.outboxRows).insert(OutboxRowsCompanion.insert(
              uid: uid,
              kind: 'listened.mark',
              entityId: 'a',
              nextAttemptAt: DateTime(2026),
              createdAt: DateTime(2026),
            ));
      }

      await store.clearAccount('me');

      expect(await store.loadListened('me'), isEmpty);
      expect(await store.loadPlaylists('me'), isEmpty);
      expect(await store.loadFollowed('me'), isEmpty);
      final outbox = await db.select(db.outboxRows).get();
      expect(outbox.map((r) => r.uid), ['other']);
      expect(await store.loadListened('other'), hasLength(2));
      expect(await store.loadPlaylists('other'), hasLength(1));
      expect(await store.loadFollowed('other'), hasLength(1));
    });
  });
}
