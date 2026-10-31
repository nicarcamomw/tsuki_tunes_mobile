import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/utils/album_categorizer.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';

Album _album(
  String id, {
  String artistId = '42',
  String artistName = 'Main Artist',
  String recordType = 'album',
}) =>
    Album(
      id: id,
      title: 'Album $id',
      coverUrl: '',
      artistId: artistId,
      artistName: artistName,
      recordType: recordType,
    );

void main() {
  const ownId = '42';
  const ownName = 'Main Artist';

  group('isOwnRelease', () {
    test('matches by artistId when present', () {
      expect(
        AlbumCategorizer.isOwnRelease(
          _album('1', artistId: ownId),
          artistId: ownId,
          artistName: ownName,
        ),
        isTrue,
      );
    });

    test('rejects different artistId when name also differs', () {
      expect(
        AlbumCategorizer.isOwnRelease(
          _album('1', artistId: '99', artistName: 'Other'),
          artistId: ownId,
          artistName: ownName,
        ),
        isFalse,
      );
    });

    test('matches by name when artistId differs but name matches', () {
      expect(
        AlbumCategorizer.isOwnRelease(
          _album('1', artistId: '99', artistName: 'Main Artist'),
          artistId: ownId,
          artistName: ownName,
        ),
        isTrue,
      );
    });

    test('falls back to name comparison when artistId is empty', () {
      expect(
        AlbumCategorizer.isOwnRelease(
          _album('1', artistId: '', artistName: 'Main Artist'),
          artistId: ownId,
          artistName: ownName,
        ),
        isTrue,
      );
    });

    test('name comparison is case-insensitive and trims whitespace', () {
      expect(
        AlbumCategorizer.isOwnRelease(
          _album('1', artistId: '', artistName: '  main artist  '),
          artistId: ownId,
          artistName: ownName,
        ),
        isTrue,
      );
    });
  });

  group('categorize', () {
    test('albums go to the album bucket', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', recordType: 'album')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['album'], hasLength(1));
      expect(cats['single'], isEmpty);
      expect(cats['ep'], isEmpty);
      expect(cats['appears_on'], isEmpty);
    });

    test('singles go to the single bucket', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', recordType: 'single')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['single'], hasLength(1));
    });

    test('eps go to the ep bucket', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', recordType: 'ep')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['ep'], hasLength(1));
    });

    test('compile records go to the ep bucket (not appears_on)', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', recordType: 'compile')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['ep'], hasLength(1));
      expect(cats['appears_on'], isEmpty);
    });

    test('unknown recordType defaults to album', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', recordType: 'live')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['album'], hasLength(1));
    });

    test('other artist albums go to appears_on', () {
      final cats = AlbumCategorizer.categorize(
        [_album('1', artistId: '99', artistName: 'Other')],
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['appears_on'], hasLength(1));
      expect(cats['album'], isEmpty);
    });

    test('mixed discography is split correctly', () {
      final albums = [
        _album('a1', recordType: 'album'),
        _album('a2', recordType: 'album'),
        _album('s1', recordType: 'single'),
        _album('e1', recordType: 'ep'),
        _album('c1', recordType: 'compile'),
        _album('f1', artistId: '99', artistName: 'Other', recordType: 'album'),
        _album('f2', artistId: '99', artistName: 'Other', recordType: 'single'),
      ];

      final cats = AlbumCategorizer.categorize(
        albums,
        artistId: ownId,
        artistName: ownName,
      );
      expect(cats['album']!.map((a) => a.id), ['a1', 'a2']);
      expect(cats['single']!.map((a) => a.id), ['s1']);
      expect(cats['ep']!.map((a) => a.id), ['e1', 'c1']);
      expect(cats['appears_on']!.map((a) => a.id), ['f1', 'f2']);
    });
  });
}
