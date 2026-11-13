import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/favorites_local_store.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

Track _song(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Band',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 180,
    );

Artist _artist(String id) => Artist(id: id, name: 'Artist $id', pictureUrl: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FavoritesLocalStore store(List<int> changes) =>
      FavoritesLocalStore(StorageService(), onChanged: () => changes.add(1));

  test('a song added is first and a favorite; toggled again it goes', () async {
    final changes = <int>[];
    final favorites = store(changes);
    await favorites.load();

    await favorites.toggleTrack(_song('1'));
    await favorites.toggleTrack(_song('2'));
    expect(favorites.tracks.map((t) => t.id), ['2', '1']);
    expect(favorites.isFavoriteTrack('1'), isTrue);

    await favorites.toggleTrack(_song('1'));
    expect(favorites.isFavoriteTrack('1'), isFalse);
    expect(favorites.tracks.map((t) => t.id), ['2']);
    expect(changes, hasLength(3), reason: 'the screens hear each change');
  });

  test('artists work the same way', () async {
    final favorites = store([]);
    await favorites.load();
    await favorites.toggleArtist(_artist('27'));
    expect(favorites.isFavoriteArtist('27'), isTrue);
    expect(favorites.artists.single.id, '27');
    await favorites.toggleArtist(_artist('27'));
    expect(favorites.artists, isEmpty);
  });

  test('saved on the phone: a fresh start reads them back', () async {
    final first = store([]);
    await first.load();
    await first.toggleTrack(_song('9'));
    await first.toggleArtist(_artist('5'));

    final again = store([]);
    await again.load();
    expect(again.tracks.map((t) => t.id), ['9']);
    expect(again.isFavoriteTrack('9'), isTrue);
    expect(again.isFavoriteArtist('5'), isTrue);
  });

  test('the same list is handed out until it changes, and it can\'t be edited from outside', () async {
    final favorites = store([]);
    await favorites.load();
    await favorites.toggleTrack(_song('1'));
    final before = favorites.tracks;
    expect(identical(favorites.tracks, before), isTrue);
    expect(() => before.add(_song('x')), throwsUnsupportedError);

    await favorites.toggleTrack(_song('2'));
    expect(identical(favorites.tracks, before), isFalse);
  });
}
