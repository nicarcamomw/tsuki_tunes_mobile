import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/catalog_repository.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_album.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/routes.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/load_by_id.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/skeleton_loader.dart';

import 'helpers/test_scope.dart';

const _album = Album(id: '123', title: 'Toxicity', coverUrl: '', artistId: 'a', artistName: 'SOAD');

class _Catalog implements CatalogRepository {
  _Catalog({this.album, this.fails = false});
  final Album? album;
  final bool fails;
  var calls = 0;

  @override
  Future<Album?> getAlbum(String albumId) async {
    calls++;
    if (fails) throw Exception('offline');
    return album?.id == albumId ? album : null;
  }

  @override
  Future<Artist?> getArtist(String id) async => null;

  @override
  Future<Track?> getTrack(String trackId) async => null;
}

Widget _page(LoadById<Album> child) => TestScope(child: MaterialApp(home: child));

void main() {
  group('GetAlbum', () {
    test('finds an album, or null when missing, blank or offline', () async {
      expect(await GetAlbum(_Catalog(album: _album))('123'), _album);
      expect(await GetAlbum(_Catalog(album: _album))('999'), isNull);
      expect(await GetAlbum(_Catalog(album: _album))(''), isNull);
      expect(await GetAlbum(_Catalog(fails: true))('123'), isNull);
    });
  });

  group('a page opened by id', () {
    testWidgets('with the object at hand it opens at once, no lookup', (tester) async {
      final catalog = _Catalog(album: _album);
      await tester.pumpWidget(_page(LoadById<Album>(
        initial: _album,
        load: (_) => GetAlbum(catalog)('123'),
        builder: (a) => Text('album ${a.title}'),
      )));
      expect(find.text('album Toxicity'), findsOneWidget);
      expect(catalog.calls, 0);
    });

    testWidgets('with only the id it loads, then shows it', (tester) async {
      await tester.pumpWidget(_page(LoadById<Album>(
        initial: null,
        load: (_) => GetAlbum(_Catalog(album: _album))('123'),
        builder: (a) => Text('album ${a.title}'),
      )));
      // The page's shape while it loads, not a spinner.
      expect(find.byType(SkeletonDetailPage), findsOneWidget);
      await tester.pump();
      expect(find.text('album Toxicity'), findsOneWidget);
    });

    testWidgets('a missing album says so and can retry', (tester) async {
      final catalog = _Catalog();
      await tester.pumpWidget(_page(LoadById<Album>(
        initial: null,
        load: (_) => GetAlbum(catalog)('404'),
        builder: (a) => Text('album ${a.title}'),
      )));
      await tester.pump();
      expect(find.text('NO ENCONTRAMOS ESTO'), findsOneWidget);
      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();
      expect(catalog.calls, 2);
    });
  });

  test('album and artist routes put the id in the path', () {
    expect(const AlbumRoute(id: '123').location, '/album/123');
    expect(const ArtistRoute(id: '27').location, '/artist/27');
    expect(const RabbitHoleRoute(id: '27').location, '/artist/27/rabbit-hole');
    expect(
      const ArtistDiscographyRoute(
        id: '27',
        filter: 'single',
        $extra: DiscographyArgs(artistName: 'x', albums: []),
      ).location,
      '/artist/27/albums?filter=single',
    );
  });
}
