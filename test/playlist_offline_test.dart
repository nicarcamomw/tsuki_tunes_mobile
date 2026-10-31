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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore server;
  late AppDatabase phone;
  late Outbox outbox;

  PlaylistRepositoryImpl open() => PlaylistRepositoryImpl(
        firebase: FakeFirebaseService(server),
        store: LibraryStore(phone),
        outbox: outbox,
      );

  Future<List<String>> serverNames() async => [
        for (final d in (await server.collection('users').doc(_uid).collection('playlists').get()).docs)
          d.data()['name'] as String,
      ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubWriteQueue.instance.gap = Duration.zero;
    server = FakeFirebaseFirestore();
    phone = AppDatabase(NativeDatabase.memory());
    outbox = Outbox(phone);
  });

  tearDown(() async {
    outbox.stop();
    await phone.close();
  });

  test('a playlist made offline shows, survives reopening and goes up when back online', () async {
    final first = open();
    await first.connectToFirestore(_uid);
    first.sendHandlerForTesting = (_) async => throw Exception('offline');
    final made = await first.createPlaylist('Noche', tracks: [_t('1')]);
    expect(first.playlists.single.name, 'Noche', reason: 'shown at once');
    await first.pendingCreations;
    expect(await serverNames(), isEmpty);
    first.disconnectFirestore();

    // Reopened, online: the server still doesn't have it, it shows anyway
    // and goes up.
    final again = open();
    await again.connectToFirestore(_uid);
    expect(again.getPlaylist(made!.id)?.name, 'Noche');
    await outbox.retryNow(_uid);
    await again.pendingCreations;
    expect(await serverNames(), ['Noche']);
    again.disconnectFirestore();
  });

  test('a playlist the server refuses for good drops out by itself', () async {
    final repo = open();
    await repo.connectToFirestore(_uid);
    repo.sendHandlerForTesting = (_) async => throw const PermanentSyncError('permission-denied');

    await repo.createPlaylist('Rechazada');
    expect(repo.playlists, hasLength(1));
    await repo.pendingCreations;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.playlists, isEmpty);
    repo.disconnectFirestore();
  });

  test('a rename still pending holds against the server copy', () async {
    final repo = open();
    await repo.connectToFirestore(_uid);
    final made = await repo.createPlaylist('Noche');
    await repo.pendingCreations;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    repo.sendHandlerForTesting = (_) async => throw Exception('offline');
    await repo.renamePlaylist(made!.id, 'Madrugada');
    await repo.pendingCreations;
    // Another device touches the playlist: its snapshot comes down.
    await server.collection('users').doc(_uid).collection('playlists').doc(made.id).update({'name': 'Noche'});
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.getPlaylist(made.id)?.name, 'Madrugada');
    repo.disconnectFirestore();
  });

  test('a guest keeps playlists on the phone only, nothing waits to go up', () async {
    final repo = open();
    await repo.initLocalOnly('guest_1');
    await repo.createPlaylist('Local');
    await repo.addTrackToPlaylist(repo.playlists.single.id, _t('1'));

    expect(repo.playlists.single.tracks.single.id, '1');
    expect(await outbox.pending('guest_1'), isEmpty);

    final reopened = open();
    await reopened.initLocalOnly('guest_1');
    expect(reopened.playlists.single.name, 'Local');
  });
}
