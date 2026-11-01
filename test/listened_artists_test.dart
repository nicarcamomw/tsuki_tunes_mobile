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

Track _catalog(String id, List<String> artists) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: artists.first,
      albumId: 'alb',
      albumTitle: 'A',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
      contributors: [for (final (i, a) in artists.indexed) Contributor(id: '$i', name: a)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new mark keeps each artist of a collaboration', () {
    final data = ListenedTrackData.fromTrack(_catalog('t', ['Bad Bunny', 'J Balvin']));
    expect(data.artists, ['Bad Bunny', 'J Balvin']);
    expect(data.hasArtistList, isTrue);
    expect(ListenedTrackData.fromJson(data.toJson()).artists, ['Bad Bunny', 'J Balvin']);
  });

  test('old songs get their real artists from the catalog, and keep them', () async {
    SharedPreferences.setMockInitialValues({});
    SubWriteQueue.instance.gap = Duration.zero;
    final server = FakeFirebaseFirestore();
    final col = server.collection('users').doc('test-user').collection('listenedTracks');
    Future<void> old(String id, String joined) => col.doc(id).set({
          'trackId': id, 'title': 'S', 'artistName': joined, 'albumTitle': '', 'albumId': '',
          'coverUrl': '', 'previewUrl': '', 'duration': 1, 'listenedAt': DateTime(2026, 1, 1),
        });
    await old('collab', 'Bad Bunny, J Balvin');
    await old('tyler', 'Tyler, The Creator');
    await old('solo', 'Bad Bunny');

    final lookups = <String>[];
    final phone = AppDatabase(NativeDatabase.memory());
    final library = LibraryRepositoryImpl(
      firebase: FakeFirebaseService(server),
      store: LibraryStore(phone),
      outbox: Outbox(phone),
      lookupTrack: (id) async {
        lookups.add(id);
        return id == 'collab' ? _catalog(id, ['Bad Bunny', 'J Balvin']) : _catalog(id, ['Tyler, The Creator']);
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await library.connectToFirestore('test-user');
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(lookups.toSet(), {'collab', 'tyler'}, reason: 'only songs with a comma are looked up');
    expect(library.uniqueArtistsCount, 3);
    expect(library.getTopArtists().first.name, 'Bad Bunny');

    // The server's copy (no list) comes down again: the repair stays.
    await col.doc('tyler').update({'title': 'S2', 'listenedAt': DateTime.now()});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(library.uniqueArtistsCount, 3);
    final rows = {for (final t in await LibraryStore(phone).loadListened('test-user')) t['trackId']: t};
    expect(rows['tyler']!['artists'], ['Tyler, The Creator']);

    library.disconnectFirestore();
    await phone.close();
  });

  test('the comma guess keeps names that hold a comma whole', () {
    List<String> g(String s) => ListenedTrackData.guessArtists(s);
    expect(g('Tyler, The Creator'), ['Tyler, The Creator']);
    expect(g('Tyler, The Creator, Kali Uchis'), ['Tyler, The Creator', 'Kali Uchis']);
    expect(g('Kali Uchis, Tyler, The Creator'), ['Kali Uchis', 'Tyler, The Creator']);
    expect(g('Earth, Wind & Fire'), ['Earth, Wind & Fire']);
    expect(g('Bad Bunny, J Balvin'), ['Bad Bunny', 'J Balvin']);
    expect(g('Bad Bunny'), ['Bad Bunny']);
    final old = ListenedTrackData(
        trackId: 't', title: 'x', artistName: 'Tyler, The Creator', albumTitle: '',
        albumId: '', coverUrl: '', duration: 1);
    expect(old.artists, ['Tyler, The Creator']);
  });
}
