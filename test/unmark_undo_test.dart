import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/local/app_database.dart';
import 'package:tsuki_tunes_mobile/data/local/library_store.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/sync/outbox.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/unmark_with_undo.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/use_cases.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/fake_firebase_service.dart';
import 'helpers/fake_library_repository.dart';
import 'helpers/test_scope.dart';

// U4: unmarking a song, or a whole album, can be undone, and the undo
// puts them back as they were (their dates too).

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the use case', () {
    test('says how many it unmarked, and the undo puts them back', () async {
      final library = FakeLibraryRepository()..listened.addAll(['1', '2', '3']);
      final done = await UnmarkWithUndo(library)(['1', '2', '3', 'never']);
      expect(done!.count, 3);
      expect(library.listened, isEmpty);
      await done.undo();
      expect(library.listened, {'1', '2', '3'});
    });

    test('nothing listened: nothing to undo', () async {
      expect(await UnmarkWithUndo(FakeLibraryRepository())(['1']), isNull);
    });
  });

  test('the undo restores each song with its own date, here and on the server', () async {
    final server = FakeFirebaseFirestore();
    final old = DateTime(2025, 3, 14, 9, 26);
    for (final id in ['1', '2']) {
      await server.collection('users').doc(_uid).collection('listenedTracks').doc(id).set({
        'trackId': id,
        'title': 'Song $id',
        'artistName': 'Artist',
        'albumTitle': 'Album',
        'albumId': 'alb',
        'coverUrl': '',
        'duration': 100,
        'listenedAt': Timestamp.fromDate(old),
      });
    }
    final phone = AppDatabase(NativeDatabase.memory());
    final library = LibraryRepositoryImpl(
        firebase: FakeFirebaseService(server), store: LibraryStore(phone), outbox: Outbox(phone));
    await library.connectToFirestore(_uid);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(library.isTrackListened('1'), isTrue);

    final done = await UnmarkWithUndo(library)(['1', '2']);
    await library.pendingWritesSentForTesting();
    final gone = await server.collection('users').doc(_uid).collection('listenedTracks').get();
    expect(gone.docs, isEmpty);

    await done!.undo();
    expect(library.isTrackListened('1'), isTrue);
    expect(library.listenedRecords(['1']).single.listenedAt, old, reason: 'not moved to the top of the history');
    await library.pendingWritesSentForTesting();
    for (final id in ['1', '2']) {
      final doc = await server.collection('users').doc(_uid).collection('listenedTracks').doc(id).get();
      expect((doc.data()!['listenedAt'] as Timestamp).toDate(), old, reason: 'the server keeps the date too ($id)');
    }
    library.disconnectFirestore();
    await phone.close();
  });

  testWidgets('unmarking from a song row offers DESHACER, which puts it back', (tester) async {
    final library = FakeLibraryRepository()..listened.add('1');
    await tester.pumpWidget(TestScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(library),
        isTrackListenedProvider('1').overrideWith((ref) => library.listened.contains('1')),
      ],
      child: MaterialApp(home: Scaffold(body: TrackTile(track: _t('1'), showListenedCheckbox: true))),
    ));
    await tester.tap(find.bySemanticsLabel('Desmarcar como escuchada'));
    await tester.pump();
    expect(library.listened, isEmpty);
    expect(find.text('Canción desmarcada'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 750)); // the snackbar slides in
    await tester.tap(find.text('DESHACER'));
    await tester.pump();
    expect(library.listened, {'1'});
  });
}
