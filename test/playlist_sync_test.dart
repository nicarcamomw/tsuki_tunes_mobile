import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/sub_write_queue.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

import 'helpers/fake_firebase_service.dart';

// T3: reordering, deleting and their conflicts, through the real repository
// and its outbox against a fake Firestore (the use case tests stand a fake
// repository in, so none of this ran there).

const _uid = 'test-user';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

/// A phone: its own database and outbox, the shared server.
class _Device {
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  late final Outbox outbox = Outbox(db);
  late final PlaylistRepositoryImpl repo;

  _Device(FakeFirebaseFirestore server) {
    repo = PlaylistRepositoryImpl(
      firebase: FakeFirebaseService(server),
      store: LibraryStore(db),
      outbox: outbox,
    );
  }

  List<String> songs(String id) => [for (final t in repo.getPlaylist(id)!.tracks) t.id];

  Future<void> close() async {
    repo.disconnectFirestore();
    outbox.stop();
    await db.close();
  }
}

Future<void> _settle() => Future.delayed(const Duration(milliseconds: 30));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore server;
  final devices = <_Device>[];

  Future<_Device> device() async {
    final d = _Device(server);
    devices.add(d);
    await d.repo.connectToFirestore(_uid);
    await _settle();
    return d;
  }

  CollectionReference<Map<String, dynamic>> playlists() =>
      server.collection('users').doc(_uid).collection('playlists');

  Future<List<String>?> serverSongs(String id) async {
    final doc = await playlists().doc(id).get();
    if (!doc.exists) return null;
    return [for (final t in doc.data()!['tracks'] as List) (t as Map)['id'].toString()];
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubWriteQueue.instance.gap = Duration.zero;
    server = FakeFirebaseFirestore();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
  });

  /// A synced playlist with songs 1..4, made on [d].
  Future<String> made(_Device d) async {
    final p = await d.repo.createPlaylist('Mix', tracks: [_t('1'), _t('2'), _t('3'), _t('4')]);
    await d.repo.pendingCreations;
    await _settle();
    return p!.id;
  }

  group('reorder', () {
    test('a song moves down and up, here at once and then on the server', () async {
      final phone = await device();
      final id = await made(phone);

      await phone.repo.reorderTrack(id, 0, 2);
      expect(phone.songs(id), ['2', '3', '1', '4']);
      await phone.repo.reorderTrack(id, 3, 0);
      expect(phone.songs(id), ['4', '2', '3', '1']);

      await phone.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), ['4', '2', '3', '1']);
    });

    test('an index outside the playlist changes nothing and sends nothing', () async {
      final phone = await device();
      final id = await made(phone);

      for (final (from, to) in [(-1, 0), (0, 4), (4, 0), (1, -2)]) {
        await phone.repo.reorderTrack(id, from, to);
      }
      expect(phone.songs(id), ['1', '2', '3', '4']);
      expect(await phone.outbox.pending(_uid), isEmpty);
    });

    test('a song another phone added meanwhile is kept, at the end', () async {
      final phone = await device();
      final id = await made(phone);
      final tablet = await device();

      // The tablet adds while the phone, offline, reorders.
      phone.repo.sendHandlerForTesting = (_) async => throw Exception('offline');
      await phone.repo.reorderTrack(id, 3, 0);
      await tablet.repo.addTrackToPlaylist(id, _t('new'));
      await tablet.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), ['1', '2', '3', '4', 'new']);

      // Back online, the phone's order goes up over the server's list.
      phone.repo.sendHandlerForTesting = null;
      await phone.outbox.retryNow(_uid);
      await phone.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), ['4', '1', '2', '3', 'new']);
      expect(phone.songs(id), ['4', '1', '2', '3', 'new']);
    });
  });

  group('delete', () {
    test('gone here at once and from the server', () async {
      final phone = await device();
      final id = await made(phone);

      await phone.repo.deletePlaylist(id);
      expect(phone.repo.getPlaylist(id), isNull);
      await phone.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), isNull);
    });

    test('offline, it stays gone after reopening and leaves the server once back', () async {
      final phone = await device();
      final id = await made(phone);

      phone.repo.sendHandlerForTesting = (_) async => throw Exception('offline');
      await phone.repo.deletePlaylist(id);
      await phone.repo.pendingCreations;
      expect(phone.repo.getPlaylist(id), isNull);
      expect(await serverSongs(id), isNotNull, reason: 'not sent yet');

      // Reopened: the server copy still has it, the pending delete hides it.
      phone.repo.disconnectFirestore();
      phone.repo.sendHandlerForTesting = null;
      final again = PlaylistRepositoryImpl(
          firebase: FakeFirebaseService(server), store: LibraryStore(phone.db), outbox: phone.outbox);
      await again.connectToFirestore(_uid);
      await _settle();
      expect(again.getPlaylist(id), isNull);

      await phone.outbox.retryNow(_uid);
      await again.pendingCreations;
      await _settle();
      expect(await serverSongs(id), isNull);
      again.disconnectFirestore();
    });

    test('another phone sees it go', () async {
      final phone = await device();
      final id = await made(phone);
      final tablet = await device();
      expect(tablet.repo.getPlaylist(id), isNotNull);

      await phone.repo.deletePlaylist(id);
      await phone.repo.pendingCreations;
      await _settle();
      expect(tablet.repo.getPlaylist(id), isNull);
    });
  });

  group('delete against an edit on another phone', () {
    test('the delete wins: a song added meanwhile neither brings it back nor stays pending', () async {
      final phone = await device();
      final id = await made(phone);
      final tablet = await device();

      // The tablet adds a song offline; the phone deletes the playlist.
      tablet.repo.sendHandlerForTesting = (_) async => throw Exception('offline');
      await tablet.repo.addTrackToPlaylist(id, _t('late'));
      expect(tablet.songs(id), contains('late'));
      await phone.repo.deletePlaylist(id);
      await phone.repo.pendingCreations;
      await _settle();
      expect(tablet.repo.getPlaylist(id), isNull, reason: 'the delete reached the tablet');

      // Back online, the tablet's add finds no playlist: it's dropped.
      tablet.repo.sendHandlerForTesting = null;
      await tablet.outbox.retryNow(_uid);
      await tablet.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), isNull);
      expect(tablet.repo.getPlaylist(id), isNull);
      expect(await tablet.outbox.pending(_uid), isEmpty, reason: 'not retried forever');
    });

    test('a rename made meanwhile does not bring it back either', () async {
      final phone = await device();
      final id = await made(phone);
      final tablet = await device();

      tablet.repo.sendHandlerForTesting = (_) async => throw Exception('offline');
      await tablet.repo.renamePlaylist(id, 'Renamed');
      await phone.repo.deletePlaylist(id);
      await phone.repo.pendingCreations;
      await _settle();

      tablet.repo.sendHandlerForTesting = null;
      await tablet.outbox.retryNow(_uid);
      await tablet.repo.pendingCreations;
      await _settle();
      expect(await serverSongs(id), isNull);
      expect(tablet.repo.getPlaylist(id), isNull);
      expect(await tablet.outbox.pending(_uid), isEmpty);
    });
  });
}
