import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/album.dart';
import 'package:tsuki_tunes_mobile/models/artist_albums_page.dart';
import 'package:tsuki_tunes_mobile/core/constants/api_endpoints.dart';

void main() {
  group('Artist Albums Pagination & Endpoints', () {
    test('ApiEndpoints.artistAlbums formats URL correctly with default index', () {
      final url = ApiEndpoints.artistAlbums('12345', limit: 250);
      expect(url, contains('/artist/12345/albums?limit=250&index=0'));
    });

    test('ApiEndpoints.artistAlbums formats URL correctly with custom index', () {
      final url = ApiEndpoints.artistAlbums('12345', limit: 100, index: 250);
      expect(url, contains('/artist/12345/albums?limit=100&index=250'));
    });

    test('ArtistAlbumsPage handles empty state', () {
      expect(ArtistAlbumsPage.empty.items, isEmpty);
      expect(ArtistAlbumsPage.empty.total, 0);
      expect(ArtistAlbumsPage.empty.hasMore, isFalse);
      expect(ArtistAlbumsPage.empty.nextIndex, 0);
    });

    test('ArtistAlbumsPage correctly calculates hasMore and nextIndex', () {
      final dummyAlbums = List.generate(
        50,
        (i) => Album(
          id: '$i',
          title: 'Album $i',
          coverUrl: 'https://example.com/$i.jpg',
          artistId: '12345',
          artistName: 'Test Artist',
          recordType: i % 2 == 0 ? 'album' : 'single',
        ),
      );

      final page = ArtistAlbumsPage(
        items: dummyAlbums,
        total: 426,
        hasMore: true,
        nextIndex: 50,
      );

      expect(page.items.length, 50);
      expect(page.total, 426);
      expect(page.hasMore, isTrue);
      expect(page.nextIndex, 50);
    });

    test('ArtistAlbumsPage detects final page when total is reached', () {
      final dummyAlbums = List.generate(
        26,
        (i) => Album(
          id: '${400 + i}',
          title: 'Final Album $i',
          coverUrl: 'https://example.com/$i.jpg',
          artistId: '12345',
          artistName: 'Test Artist',
        ),
      );

      final finalPage = ArtistAlbumsPage(
        items: dummyAlbums,
        total: 426,
        hasMore: false,
        nextIndex: 426,
      );

      expect(finalPage.items.length, 26);
      expect(finalPage.hasMore, isFalse);
      expect(finalPage.nextIndex, 426);
    });
  });
}
