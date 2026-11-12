import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

import 'helpers/fake_firebase_service.dart';

const uid = 'user_1';

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

Future<void> _seed(FakeFirebaseFirestore db, String id, DateTime at) =>
    db.collection('users').doc(uid).collection('listenedTracks').doc(id).set({
      'trackId': id,
      'title': 'Track $id',
      'artistName': 'Artist',
      'albumTitle': 'Album',
      'albumId': 'alb',
      'coverUrl': '',
      'duration': 100,
      'listenedAt': Timestamp.fromDate(at),
    });

Future<void> _settle() => Future.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
  });

  /// A device; pass the same [local] database to restart the same phone.
  LibraryRepositoryImpl newDevice({AppDatabase? local}) {
    final phone = local ?? AppDatabase(NativeDatabase.memory());
    return LibraryRepositoryImpl(
      firebase: FakeFirebaseService(db),
      store: LibraryStore(phone),
      outbox: Outbox(phone),
    );
  }

  group('listened tracks sync', () {
    test('first connect does a full fetch and fixes the stats counter',
        () async {
      final old = DateTime(2026, 1, 1);
      await _seed(db, 't1', old);
      await _seed(db, 't2', old);
      await db.collection('users').doc(uid).set({
        'stats': {'totalTracks': 7}, // drifted
      });

      final device = newDevice();
      await device.connectToFirestore(uid);
      await _settle();

      expect(device.listenedTrackIds, {'t1', 't2'});
      expect(await StorageService().getLastListenedFullSync(uid), isNotNull);
      final user = await db.collection('users').doc(uid).get();
      expect((user.data()!['stats'] as Map)['totalTracks'], 2);
    });

    test('reconnect within a day uses cache + delta, not a full fetch',
        () async {
      final old = DateTime(2026, 1, 1);
      await _seed(db, 't1', old);
      final phone = AppDatabase(NativeDatabase.memory());
      final first = newDevice(local: phone);
      await first.connectToFirestore(uid);
      await _settle();
      first.disconnectFirestore();

      // A doc older than everything cached would only come from a full
      // fetch; a new one must arrive through the delta listener.
      await _seed(db, 'ancient', DateTime(2020));
      await _seed(db, 'fresh', DateTime.now());

      final second = newDevice(local: phone); // the same phone, reopened
      await second.connectToFirestore(uid);
      await _settle();

      expect(second.isTrackListened('t1'), isTrue);
      expect(second.isTrackListened('fresh'), isTrue);
      expect(second.isTrackListened('ancient'), isFalse);
    });

    test('an unmark on another device removes an old track here', () async {
      await _seed(db, 'old', DateTime(2026, 1, 1));
      await _seed(db, 'keep', DateTime(2026, 1, 1));

      final phone = newDevice();
      await phone.connectToFirestore(uid);
      await _settle();
      expect(phone.isTrackListened('old'), isTrue);

      final tablet = newDevice();
      await tablet.connectToFirestore(uid);
      await _settle();
      await tablet.unmarkTrack('old');
      await _settle();

      final log = await db
          .collection('users')
          .doc(uid)
          .collection('listenedDeletions')
          .doc('old')
          .get();
      expect(log.exists, isTrue);
      expect(phone.isTrackListened('old'), isFalse);
      expect(phone.isTrackListened('keep'), isTrue);
    });

    test('marking writes the track and keeps it after a stale deletion',
        () async {
      final phone = newDevice();
      await phone.connectToFirestore(uid);
      await _settle();

      await phone.markTrack(_track('t9'));
      await phone.pendingWritesSentForTesting();
      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('listenedTracks')
          .doc('t9')
          .get();
      expect(doc.exists, isTrue);

      // A deletion logged before this mark must not remove it.
      expect(
          phone.applyRemoteDeletion('t9', DateTime(2026, 1, 1)), isFalse);
      expect(phone.isTrackListened('t9'), isTrue);
    });

    test('back after more than a week, a failed full download is owed and '
        'tried again: the unmarks made meanwhile arrive', () async {
      await _seed(db, 'old', DateTime(2026, 1, 1));
      await _seed(db, 'keep', DateTime(2026, 1, 1));
      final local = AppDatabase(NativeDatabase.memory());
      final phone = newDevice(local: local);
      await phone.connectToFirestore(uid);
      await _settle();
      expect(phone.isTrackListened('old'), isTrue);
      phone.disconnectFirestore();

      // Away for 8 days: 'old' was unmarked elsewhere, and its entry in the
      // deletion log is already gone (kept 7 days).
      await StorageService().saveLastListenedFullSync(
          uid, DateTime.now().subtract(const Duration(days: 8)));
      await db.collection('users').doc(uid).collection('listenedTracks').doc('old').delete();

      // Back with a bad network: the full download fails, the song stays...
      final again = newDevice(local: local);
      again.failFullDownloadsForTesting = 1;
      await again.connectToFirestore(uid);
      await _settle();
      expect(again.owesFullSyncForTesting, isTrue);
      expect(again.isTrackListened('old'), isTrue);

      // ...until the owed download is tried again (a timer, or the
      // connection coming back), instead of waiting for the next start.
      await again.retryOwedFullSyncForTesting();
      await _settle();
      expect(again.owesFullSyncForTesting, isFalse);
      expect(again.isTrackListened('old'), isFalse);
      expect(again.isTrackListened('keep'), isTrue);
      again.disconnectFirestore();
    });

    test('songs marked here and not sent yet survive the owed download', () async {
      await _seed(db, 'server', DateTime(2026, 1, 1));
      final device = newDevice();
      device.failFullDownloadsForTesting = 1;
      await device.connectToFirestore(uid);
      await _settle();
      expect(device.owesFullSyncForTesting, isTrue);

      // A mark whose write can't reach the server (no network): it stays
      // pending on the phone.
      device.markAlbumChunkHandlerForTesting =
          (_, __) async => throw FirebaseException(plugin: 'firestore', code: 'unavailable');
      await device.markTrack(_track('mine'));
      await _settle();

      await device.retryOwedFullSyncForTesting();
      await _settle();
      expect(device.isTrackListened('server'), isTrue);
      expect(device.isTrackListened('mine'), isTrue);
      device.disconnectFirestore();
    });

    // B5: the counter used to be a client-side increment, so a song marked
    // on two devices before they synced counted twice.
    test('the same song marked on two devices counts once', () async {
      final phone = newDevice();
      final tablet = newDevice();
      await phone.connectToFirestore(uid);
      await tablet.connectToFirestore(uid);
      await _settle();

      await phone.markTrack(_track('same'));
      await tablet.markTrack(_track('same'));
      await phone.pendingWritesSentForTesting();
      await tablet.pendingWritesSentForTesting();
      await _settle();

      final user = await db.collection('users').doc(uid).get();
      expect((user.data()!['stats'] as Map)['totalTracks'], 1);
      expect(phone.listenedCount, 1);
      expect(tablet.listenedCount, 1);
      phone.disconnectFirestore();
      tablet.disconnectFirestore();
    });

    test('a normal connect owes nothing; disconnecting forgets what was owed', () async {
      await _seed(db, 't1', DateTime(2026, 1, 1));
      final ok = newDevice();
      await ok.connectToFirestore(uid);
      await _settle();
      expect(ok.owesFullSyncForTesting, isFalse);
      ok.disconnectFirestore();

      final flaky = newDevice();
      flaky.failFullDownloadsForTesting = 5;
      await flaky.connectToFirestore(uid);
      await _settle();
      expect(flaky.owesFullSyncForTesting, isTrue);
      flaky.disconnectFirestore();
      expect(flaky.owesFullSyncForTesting, isFalse);
    });
  });

  group('playlists', () {
    test('a new playlist shows up once, not twice', () async {
      final phone = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      final created = await phone.createPlaylist('metal', tracks: [_track('a')]);
      await phone.pendingCreations;
      await _settle();
      expect(phone.playlists.map((p) => p.id), [created!.id]);
      final docs = await db
          .collection('users')
          .doc(uid)
          .collection('playlists')
          .get();
      expect(docs.docs.length, 1);
    });

    test('creating the same playlist twice in a row makes only one',
        () async {
      final phone = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      await Future.wait([
        phone.createPlaylist('metal'),
        phone.createPlaylist('metal'),
      ]);
      await phone.pendingCreations;
      await _settle();
      expect(phone.playlists.length, 1);
    });

    // B7: signing in with Google after using the app as a guest moves the
    // guest's playlists (kept on the phone only) into the account.
    test('a guest\'s playlists move into the account on sign-in, once', () async {
      const guest = 'guest_abc';
      final repo = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await repo.initLocalOnly(guest);
      await repo.createPlaylist('Noche', tracks: [_track('a'), _track('b')]);
      expect(repo.playlists.single.name, 'Noche');

      await repo.connectToFirestore(uid);
      await repo.importGuestPlaylists(guest);
      await repo.pendingCreations;
      await _settle();

      final docs = await db.collection('users').doc(uid).collection('playlists').get();
      expect(docs.docs.map((d) => d.data()['name']), ['Noche']);
      expect(repo.playlists.single.tracks.map((t) => t.id), ['a', 'b']);

      // Nothing left behind to import twice.
      await repo.importGuestPlaylists(guest);
      await repo.pendingCreations;
      await _settle();
      final again = await db.collection('users').doc(uid).collection('playlists').get();
      expect(again.docs, hasLength(1));
      repo.disconnectFirestore();
    });

    test('duplicates saved earlier in the cache are dropped', () async {
      final storage = StorageService();
      final p = {
        'id': 'p1',
        'name': 'metal',
        'tracks': <Map<String, dynamic>>[],
        'createdAt': DateTime(2026).toIso8601String(),
        'updatedAt': DateTime(2026).toIso8601String(),
      };
      await storage.saveCachedPlaylists('guest_x', [p, p]);
      final phone = PlaylistRepositoryImpl(storage: storage);
      await phone.initLocalOnly('guest_x');
      expect(phone.playlists.length, 1);
    });

    // fake_cloud_firestore runs transactions without conflict detection, so
    // truly simultaneous writes can't be simulated (real Firestore retries
    // them). What this checks is that each write merges into the server copy
    // instead of overwriting it with the device's own list.
    test('adds from two devices are both kept', () async {
      final phone = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      final created = await phone.createPlaylist('Mix');
      await phone.pendingCreations;
      await _settle();
      final id = phone.playlists.first.id;
      expect(created, isNotNull);

      final tablet = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await tablet.connectToFirestore(uid);
      await _settle();

      // Another device's write lands on the server, and the tablet adds in
      // the same turn, before its listener can deliver that change.
      final docRef =
          db.collection('users').doc(uid).collection('playlists').doc(id);
      final remoteWrite = docRef.update({
        'tracks': FieldValue.arrayUnion([_track('a').toJson()]),
      });
      final tabletAdd = tablet.addTrackToPlaylist(id, _track('b'));
      expect(tablet.getPlaylist(id)!.tracks.map((t) => t.id), ['b']);
      await Future.wait([remoteWrite, tabletAdd]);
      // The add goes up through the outbox.
      await tablet.pendingCreations;
      await _settle();

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('playlists')
          .doc(id)
          .get();
      final ids = (doc.data()!['tracks'] as List)
          .map((t) => (t as Map)['id'])
          .toSet();
      expect(ids, {'a', 'b'});
    });

    test('removing on one device keeps a track added on the other',
        () async {
      final phone = PlaylistRepositoryImpl(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      await phone.createPlaylist('Mix');
      await phone.pendingCreations;
      await _settle();
      final id = phone.playlists.first.id;
      await phone.addTrackToPlaylist(id, _track('a'));
      await phone.pendingCreations;
      await _settle();

      // Another device adds 'b' while the phone, not yet aware of it,
      // removes 'a'.
      final docRef =
          db.collection('users').doc(uid).collection('playlists').doc(id);
      final remoteAdd = docRef.update({
        'tracks': FieldValue.arrayUnion([_track('b').toJson()]),
      });
      final phoneRemove = phone.removeTrackFromPlaylist(id, 'a');
      expect(phone.getPlaylist(id)!.tracks, isEmpty);
      await Future.wait([remoteAdd, phoneRemove]);
      await phone.pendingCreations;
      await _settle();

      final doc = await docRef.get();
      final ids =
          (doc.data()!['tracks'] as List).map((t) => (t as Map)['id']).toList();
      expect(ids, ['b']);
    });
  });
}
