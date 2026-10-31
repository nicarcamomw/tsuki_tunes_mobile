import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/library_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/playlist_provider.dart';

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

  LibraryProvider newDevice() =>
      LibraryProvider(firebase: FakeFirebaseService(db));

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
      expect(user.data()!['stats']['totalTracks'], 2);
    });

    test('reconnect within a day uses cache + delta, not a full fetch',
        () async {
      final old = DateTime(2026, 1, 1);
      await _seed(db, 't1', old);
      final first = newDevice();
      await first.connectToFirestore(uid);
      await _settle();
      first.disconnectFirestore();

      // A doc older than everything cached would only come from a full
      // fetch; a new one must arrive through the delta listener.
      await _seed(db, 'ancient', DateTime(2020));
      await _seed(db, 'fresh', DateTime.now());

      final second = newDevice();
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
      await _settle();
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
  });

  group('playlists', () {
    test('a new playlist shows up once, not twice', () async {
      final phone = PlaylistProvider(firebase: FakeFirebaseService(db));
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
      final phone = PlaylistProvider(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      await Future.wait([
        phone.createPlaylist('metal'),
        phone.createPlaylist('metal'),
      ]);
      await phone.pendingCreations;
      await _settle();
      expect(phone.playlists.length, 1);
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
      final phone = PlaylistProvider(storage: storage);
      await phone.initLocalOnly('guest_x');
      expect(phone.playlists.length, 1);
    });

    // fake_cloud_firestore runs transactions without conflict detection, so
    // truly simultaneous writes can't be simulated (real Firestore retries
    // them). What this checks is that each write merges into the server copy
    // instead of overwriting it with the device's own list.
    test('adds from two devices are both kept', () async {
      final phone = PlaylistProvider(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      final created = await phone.createPlaylist('Mix');
      await phone.pendingCreations;
      await _settle();
      final id = phone.playlists.first.id;
      expect(created, isNotNull);

      final tablet = PlaylistProvider(firebase: FakeFirebaseService(db));
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
      final phone = PlaylistProvider(firebase: FakeFirebaseService(db));
      await phone.connectToFirestore(uid);
      await phone.createPlaylist('Mix');
      await phone.pendingCreations;
      await _settle();
      final id = phone.playlists.first.id;
      await phone.addTrackToPlaylist(id, _track('a'));
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
      await _settle();

      final doc = await docRef.get();
      final ids =
          (doc.data()!['tracks'] as List).map((t) => (t as Map)['id']).toList();
      expect(ids, ['b']);
    });
  });
}
