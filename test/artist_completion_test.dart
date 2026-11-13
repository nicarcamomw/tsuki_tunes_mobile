import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/logic/artist_completion.dart';

// The mask on an artist's page: lit when every own release of theirs has
// been heard from start to end.

Album _album(String id, String title, {String type = 'album', String artistId = '27'}) => Album(
    id: id, title: title, coverUrl: '', artistId: artistId, artistName: 'Daft Punk', recordType: type);

void main() {
  bool own(Album a) => a.artistId == '27' && a.recordType != 'compile';

  ArtistCompletion of(List<Album> albums, Set<String> done, {bool loaded = true}) => ArtistCompletion.of(
        albums,
        isOwnRelease: own,
        isAlbumCompleted: (a) => done.contains(a.id),
        loaded: loaded,
      );

  final discography = [
    _album('1', 'Homework'),
    _album('2', 'Discovery'),
    _album('3', 'One More Time', type: 'single'),
  ];

  test('lit once every own release is complete', () {
    expect(of(discography, {'1', '2'}).isComplete, isFalse);
    final all = of(discography, {'1', '2', '3'});
    expect(all.isComplete, isTrue);
    expect((all.completed, all.total), (3, 3));
  });

  test('counts how far along the discography is', () {
    final c = of(discography, {'2'});
    expect((c.completed, c.total), (1, 3));
  });

  test('editions of the same release count once, and any of them completes it', () {
    final albums = [...discography, _album('2e', 'Discovery '), _album('2c', 'DISCOVERY')];
    final c = of(albums, {'1', '2c', '3'});
    expect(c.total, 3);
    expect(c.isComplete, isTrue);
  });

  test('an album and a single with the same title are different releases', () {
    final albums = [_album('a', 'Get Lucky'), _album('s', 'Get Lucky', type: 'single')];
    expect(of(albums, {'a'}).isComplete, isFalse);
    expect(of(albums, {'a', 's'}).total, 2);
  });

  test('features and compilations do not count', () {
    final albums = [
      ...discography,
      _album('f', 'Starboy', artistId: '999'),
      _album('c', 'Greatest Hits', type: 'compile'),
    ];
    final c = of(albums, {'1', '2', '3'});
    expect(c.total, 3);
    expect(c.isComplete, isTrue);
  });

  test('not lit while the discography is still loading or has more pages', () {
    final c = of(discography, {'1', '2', '3'}, loaded: false);
    expect(c.isComplete, isFalse);
    expect(c.completed, 3);
  });

  test('an artist with no own release is never complete', () {
    final c = of([_album('f', 'Starboy', artistId: '999')], {'f'});
    expect((c.completed, c.total, c.isComplete), (0, 0, false));
  });
}
