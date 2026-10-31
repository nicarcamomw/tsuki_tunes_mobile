import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/sub_write_queue.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/followed_artists_repository.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';

import 'helpers/fake_firebase_service.dart';

const _uid = 'test-user';
const _soad = Artist(id: '27', name: 'SOAD', pictureUrl: '');
const _korn = Artist(id: '3', name: 'Korn', pictureUrl: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore server;
  late AppDatabase phone;
  late Outbox outbox;
  late LibraryRepositoryImpl library;

  Future<bool> onServer(String id) async =>
      (await server.collection('users').doc(_uid).collection('followedArtists').doc(id).get()).exists;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SubWriteQueue.instance.gap = Duration.zero;
    server = FakeFirebaseFirestore();
    phone = AppDatabase(NativeDatabase.memory());
    outbox = Outbox(phone);
    library = LibraryRepositoryImpl(
      firebase: FakeFirebaseService(server),
      store: LibraryStore(phone),
      outbox: outbox,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    library.disconnectFirestore();
    await phone.close();
  });

  test('following and unfollowing reach the server', () async {
    await library.connectToFirestore(_uid);
    await library.followArtist(_soad);
    expect(library.isArtistFollowed('27'), isTrue, reason: 'shown at once');
    await library.pendingWritesSentForTesting();
    expect(await onServer('27'), isTrue);

    await library.unfollowArtist('27');
    await library.pendingWritesSentForTesting();
    expect(await onServer('27'), isFalse);
  });

  test('a follow left pending last time survives the server list, then goes up', () async {
    // Followed offline before the app closed: only the outbox has it.
    await outbox.enqueue(_uid, FollowedArtistsRepository.followKind, '3', {'artist': _korn.toJson()});
    await server.collection('users').doc(_uid).collection('followedArtists').doc('27').set(_soad.toJson());

    await library.connectToFirestore(_uid);
    await library.pendingWritesSentForTesting();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(library.isArtistFollowed('27'), isTrue);
    expect(library.isArtistFollowed('3'), isTrue);
    expect(await onServer('3'), isTrue);
  });

  test('a follow refused for good is undone', () async {
    await library.connectToFirestore(_uid);
    library.followSendHandlerForTesting = (_) async => throw const PermanentSyncError('permission-denied');

    await library.followArtist(_korn);
    expect(library.isArtistFollowed('3'), isTrue, reason: 'shown at once');
    await library.pendingWritesSentForTesting();
    expect(library.isArtistFollowed('3'), isFalse);
    expect(await onServer('3'), isFalse);
  });

  test('an unfollow refused for good brings the artist back', () async {
    await library.connectToFirestore(_uid);
    await library.followArtist(_soad);
    await library.pendingWritesSentForTesting();
    library.followSendHandlerForTesting = (_) async => throw const PermanentSyncError('permission-denied');

    await library.unfollowArtist('27');
    await library.pendingWritesSentForTesting();
    expect(library.isArtistFollowed('27'), isTrue);
  });
}
