import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/play_history.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart' show artistPlaysOf;

ListenedTrackData _t(String id, String artist) => ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: artist,
      albumTitle: '',
      albumId: '',
      coverUrl: '',
      previewUrl: '',
      duration: 200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the artist ranking is reused until the library changes', () async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryRepositoryImpl();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await library.setListenedTracksForTesting([_t('1', 'A'), _t('2', 'A'), _t('3', 'B')]);

    final first = library.getTopArtists(limit: 2);
    expect(first.map((e) => e.name), ['A', 'B']);
    expect(library.getTopArtists(limit: 1).single.name, 'A');

    // Five visits to B (score 5) overtake A's two listened songs (score 4).
    for (var i = 0; i < 5; i++) {
      await library.trackArtistVisit('B');
    }
    expect(library.getTopArtists(limit: 1).single.name, 'B');
  });

  test('what really played counts: the most heard artist leads, with its plays in its points', () async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryRepositoryImpl();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Two songs of A marked; C never marked but played a lot.
    await library.setListenedTracksForTesting([_t('1', 'A'), _t('2', 'A')]);
    Track song(String id, String artist) => Track(
        id: id, title: 'S$id', artistId: '', artistName: artist, albumId: '', albumTitle: '',
        coverUrl: '', previewUrl: '', durationSeconds: 180);
    final history = PlayHistory();
    for (var i = 0; i < 7; i++) {
      await history.record(song('c$i', 'C'));
    }
    await history.record(song('1', 'A'));

    library.setArtistPlays(artistPlaysOf(history));
    final top = library.getTopArtists(limit: 2);
    expect(top.map((e) => e.name), ['C', 'A']);
    expect(top.first.score, 7, reason: '7 plays');
    expect(top.first.plays, 7);
    expect(top.last.score, 5, reason: '2 marked × 2 + 1 play');

    // The same plays again change nothing (no needless rebuilds).
    var told = 0;
    library.addListener(() => told++);
    library.setArtistPlays(artistPlaysOf(history));
    expect(told, 0);
  });

  test('the listened list is the same object until it changes', () async {
    // The library screen regroups thousands of tracks only when this
    // object changes.
    SharedPreferences.setMockInitialValues({});
    final library = LibraryRepositoryImpl();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await library.setListenedTracksForTesting([_t('1', 'A'), _t('2', 'B')]);

    final first = library.listenedTracks;
    expect(identical(library.listenedTracks, first), isTrue);

    // Something else in the library changing keeps the same list.
    await library.trackArtistVisit('A');
    final afterVisit = library.listenedTracks;
    expect(identical(afterVisit, first), isTrue);

    // A remote unmark gives a new list with the change.
    library.applyRemoteDeletion('2', DateTime.now());
    final afterDeletion = library.listenedTracks;
    expect(identical(afterDeletion, afterVisit), isFalse);
    expect(afterDeletion.map((t) => t.trackId), ['1']);
  });
}
