import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/sub_write_queue.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

import 'helpers/fake_firebase_service.dart';

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

// While songs play one after another, each is marked as listened as the
// previous marks come back confirmed from the server. No mark may be lost.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('marks made while server changes arrive are never lost', () async {
    SharedPreferences.setMockInitialValues({});
    SubWriteQueue.instance.gap = Duration.zero;
    final server = FakeFirebaseFirestore();
    final phone = AppDatabase(NativeDatabase.memory());
    final library = LibraryRepositoryImpl(
      firebase: FakeFirebaseService(server),
      store: LibraryStore(phone),
      outbox: Outbox(phone),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await library.connectToFirestore('test-user');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final remote = server.collection('users').doc('test-user').collection('listenedTracks');
    for (var i = 0; i < 40; i++) {
      // Another device's mark lands on the server...
      final at = DateTime.now();
      final remoteWrite = remote.doc('r$i').set({
        'trackId': 'r$i', 'title': 'R$i', 'artistName': 'X', 'albumTitle': '', 'albumId': '',
        'coverUrl': '', 'previewUrl': '', 'duration': 1, 'listenedAt': at,
      });
      // ...while this device marks the song that just passed the threshold.
      final localMark = library.markTrack(_t('l$i'));
      await Future.wait([remoteWrite, localMark]);
      await Future<void>.delayed(Duration(milliseconds: i % 3));
    }
    await library.pendingWritesSentForTesting();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final missing = [for (var i = 0; i < 40; i++) if (!library.isTrackListened('l$i')) 'l$i'];
    expect(missing, isEmpty, reason: 'marks lost from what the screens show');
    library.disconnectFirestore();
    await phone.close();
  });
}
