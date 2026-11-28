import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/app_router.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/routes.dart';

/// Runs every route-level redirect go_router runs for [location] with
/// [extra], as it does on a push. Each one builds its route from the
/// state, reading the extra as its own type: a route in the match that
/// expects another type throws (the artist page's "Ver más" did, as
/// "type 'DiscographyArgs' is not a subtype of type 'Artist?'").
void _redirectAll(BuildContext context, String location, Object? extra) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: $appRoutes,
    initialLocation: '/loading',
  );
  addTearDown(router.dispose);
  final config = router.configuration;
  final matches = config.findMatch(Uri.parse(location), extra: extra);
  expect(matches.isError, isFalse, reason: location);
  expect(matches.uri.path, location.split('?').first);
  matches.visitRouteMatches((match) {
    match.route.redirect?.call(
      context,
      match.buildState(config, matches, metadata: matches.metadataFor(match)),
    );
    return true;
  });
}

const _artist = Artist(id: '27', name: 'Lamb of God', pictureUrl: '');
const _album = Album(id: '1', title: 'Omens', coverUrl: '', artistId: '27', artistName: 'Lamb of God');

void main() {
  testWidgets('each artist page takes its own extra', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }));

    // "Ver más": the full discography, with the albums the artist page had.
    _redirectAll(
      context,
      '/artist/27/albums?filter=album',
      const DiscographyArgs(artistName: 'Lamb of God', albums: [_album], totalAlbums: 40),
    );
    // From a link, or restored after the login: no extra at all.
    _redirectAll(context, '/artist/27/albums', null);
    _redirectAll(context, '/artist/27/rabbit-hole', _artist);
    _redirectAll(context, '/artist/27', _artist);
    _redirectAll(context, '/album/1', _album);
  });

  test('the discography opens without an extra', () {
    expect(const ArtistDiscographyRoute(id: '27').location, '/artist/27/albums');
  });
}
