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
}
