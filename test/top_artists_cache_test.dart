import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';

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
    final library = LibraryProvider();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    library.setListenedTracksForTesting([_t('1', 'A'), _t('2', 'A'), _t('3', 'B')]);

    final first = library.getTopArtists(limit: 2);
    expect(first.map((e) => e.name), ['A', 'B']);
    expect(library.getTopArtists(limit: 1).single.name, 'A');

    // Five visits to B (score 5) overtake A's two listened songs (score 4).
    for (var i = 0; i < 5; i++) {
      await library.trackArtistVisit('B');
    }
    expect(library.getTopArtists(limit: 1).single.name, 'B');
  });

  test('the listened list is the same object until it changes', () async {
    // The library screen regroups thousands of tracks only when this
    // object changes.
    SharedPreferences.setMockInitialValues({});
    final library = LibraryProvider();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    library.setListenedTracksForTesting([_t('1', 'A'), _t('2', 'B')]);

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
