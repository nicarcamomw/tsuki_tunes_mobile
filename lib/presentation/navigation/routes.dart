import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../screens/album_detail_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/artist_discography_screen.dart';
import '../screens/bonds_screen.dart';
import '../screens/discovery_screen.dart';
import '../screens/genre_screen.dart';
import '../screens/guess_song_screen.dart';
import '../screens/listening_clock_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/mask_collection_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/party_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/rabbit_hole_screen.dart';
import '../screens/release_radar_screen.dart';
import '../screens/run_mode_screen.dart';
import '../screens/shared_playlist_screen.dart';
import '../screens/spotify_import_screen.dart';
import '../screens/time_machine_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/wrapped_screen.dart';
import '../state/use_cases.dart';
import '../widgets/load_by_id.dart';
import 'app_router.dart';

part 'routes.g.dart';

// The app's routes, typed: `const PlaylistRoute(id: 'x').push(context)`
// instead of building a screen and a page route by hand, and the same
// classes read a deep link's path. go_router_builder writes routes.g.dart
// (dart run build_runner build -d).

// --- Session gates (the router's redirect moves between them)

@TypedGoRoute<LoadingRoute>(path: AppPaths.loading)
class LoadingRoute extends GoRouteData with $LoadingRoute {
  const LoadingRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadePage(state, const Scaffold(backgroundColor: Color(0xFF181B22)));
}

@TypedGoRoute<LoginRoute>(path: AppPaths.login)
class LoginRoute extends GoRouteData with $LoginRoute {
  const LoginRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadePage(state, const LoginScreen());
}

@TypedGoRoute<OnboardingRoute>(path: AppPaths.onboarding)
class OnboardingRoute extends GoRouteData with $OnboardingRoute {
  const OnboardingRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      fadePage(state, const OnboardingScreen());
}

// --- The main screen: tabs, with pages pushed over them inside the shell
// (bottom bar and mini player stay) or over everything (root navigator).

@TypedShellRoute<MainShellRoute>(
  routes: [
    TypedGoRoute<HomeRoute>(
      path: AppPaths.home,
      routes: [
        TypedGoRoute<AlbumRoute>(path: 'album/:id'),
        TypedGoRoute<ArtistRoute>(
          path: 'artist/:id',
          routes: [
            TypedGoRoute<ArtistDiscographyRoute>(path: 'albums'),
            TypedGoRoute<RabbitHoleRoute>(path: 'rabbit-hole'),
          ],
        ),
        TypedGoRoute<PlaylistRoute>(path: 'playlist/:id'),
        TypedGoRoute<TrackRoute>(path: 'track/:id'),
        TypedGoRoute<UserProfileRoute>(path: 'user/:uid'),
        TypedGoRoute<BondsRoute>(path: 'bonds'),
        TypedGoRoute<DiscoveryRoute>(path: 'discover'),
        TypedGoRoute<SpotifyImportRoute>(path: 'import-spotify'),
        TypedGoRoute<SharedPlaylistRoute>(path: 'shared/:id'),
        TypedGoRoute<PartyRoute>(path: 'party'),
        TypedGoRoute<ReleaseRadarRoute>(path: 'radar'),
        TypedGoRoute<TimeMachineRoute>(path: 'time-machine'),
        TypedGoRoute<ListeningClockRoute>(path: 'listening-clock'),
        TypedGoRoute<GuessSongRoute>(path: 'guess'),
        TypedGoRoute<RunModeRoute>(path: 'run'),
        TypedGoRoute<MaskCollectionRoute>(path: 'masks'),
        TypedGoRoute<WrappedRoute>(path: 'wrapped/:year'),
        TypedGoRoute<TutorialRoute>(path: 'tutorial'),
        TypedGoRoute<GenreRoute>(path: 'genre/:id'),
      ],
    ),
  ],
)
class MainShellRoute extends ShellRouteData {
  const MainShellRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = appNavigatorKey;
  static final List<NavigatorObserver> $observers = [shellNavigatorObserver];

  @override
  Page<void> pageBuilder(BuildContext context, GoRouterState state, Widget navigator) =>
      fadePage(state, MainNavigationScreen(child: navigator));
}

/// The three tabs.
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MainTabsView();
}

/// An album. [$extra] is the album when the caller has it (it opens at
/// once); a link brings only the id, and it loads.
class AlbumRoute extends GoRouteData with $AlbumRoute {
  const AlbumRoute({required this.id, this.$extra});

  final String id;
  final Album? $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        LoadById<Album>(
          initial: $extra,
          load: (ref) => ref.read(getAlbumProvider)(id),
          builder: (album) => AlbumDetailScreen(album: album),
        ),
      );
}

/// An artist; like [AlbumRoute], loads when it only has the id.
class ArtistRoute extends GoRouteData with $ArtistRoute {
  const ArtistRoute({required this.id, this.$extra});

  final String id;
  final Artist? $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        LoadById<Artist>(
          initial: $extra,
          load: (ref) => ref.read(getArtistProvider)(id),
          builder: (artist) => ArtistDetailScreen(artist: artist),
        ),
      );
}

/// What the artist page already loaded, handed to the full discography.
class DiscographyArgs {
  const DiscographyArgs({required this.artistName, required this.albums, this.totalAlbums = 0});

  final String artistName;
  final List<Album> albums;
  final int totalAlbums;
}

/// The artist's full discography, filtered by [filter] (all, album,
/// single...). Opened from the artist page, which hands over the albums it
/// has ([$extra]); it pops with the longer list it loaded.
class ArtistDiscographyRoute extends GoRouteData with $ArtistDiscographyRoute {
  const ArtistDiscographyRoute({required this.id, this.filter = 'all', required this.$extra});

  final String id;
  final String filter;
  final DiscographyArgs $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        ArtistDiscographyScreen(
          artistId: id,
          artistName: $extra.artistName,
          albums: $extra.albums,
          totalAlbums: $extra.totalAlbums,
          initialFilter: filter,
        ),
      );
}

/// Rabbit hole: one related artist after another, starting from this one.
class RabbitHoleRoute extends GoRouteData with $RabbitHoleRoute {
  const RabbitHoleRoute({required this.id, this.$extra});

  final String id;
  final Artist? $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        LoadById<Artist>(
          initial: $extra,
          load: (ref) => ref.read(getArtistProvider)(id),
          builder: (artist) => RabbitHoleScreen(seedArtist: artist),
        ),
      );
}

/// A song link (tsukitunes://track/123): plays it and shows its album.
class TrackRoute extends GoRouteData with $TrackRoute {
  const TrackRoute({required this.id});

  final String id;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        LoadById<Track>(
          initial: null,
          load: (ref) => ref.read(getTrackProvider)(id),
          builder: (track) => _PlayingTrackAlbum(track: track),
        ),
      );
}

/// Starts [track] once, then is its album page.
class _PlayingTrackAlbum extends ConsumerStatefulWidget {
  const _PlayingTrackAlbum({required this.track});

  final Track track;

  @override
  ConsumerState<_PlayingTrackAlbum> createState() => _PlayingTrackAlbumState();
}

class _PlayingTrackAlbumState extends ConsumerState<_PlayingTrackAlbum> {
  @override
  void initState() {
    super.initState();
    ref.read(playTrackProvider)(widget.track, queue: [widget.track]);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return AlbumDetailScreen(
      album: Album(
        id: t.albumId,
        title: t.albumTitle,
        coverUrl: t.coverUrl,
        artistId: t.artistId,
        artistName: t.artistName,
      ),
    );
  }
}

/// A user's public profile (`tsukitunes://user/<uid>`).
class UserProfileRoute extends GoRouteData with $UserProfileRoute {
  const UserProfileRoute({required this.uid});

  final String uid;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, UserProfileScreen(uid: uid));
}

/// Listening together.
class PartyRoute extends GoRouteData with $PartyRoute {
  const PartyRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(state, const PartyScreen());
}

/// A collaborative playlist.
class SharedPlaylistRoute extends GoRouteData with $SharedPlaylistRoute {
  const SharedPlaylistRoute({required this.id});

  final String id;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(state, SharedPlaylistScreen(id: id));
}

/// Bring Spotify playlists into Tsuki.
class SpotifyImportRoute extends GoRouteData with $SpotifyImportRoute {
  const SpotifyImportRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(state, const SpotifyImportScreen());
}

/// Discovery: swipe through new songs.
class DiscoveryRoute extends GoRouteData with $DiscoveryRoute {
  const DiscoveryRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(state, const DiscoveryScreen());
}

/// Bonds (Lazos): Resonances, Bonds and requests, and search.
class BondsRoute extends GoRouteData with $BondsRoute {
  const BondsRoute({this.tab = 0});

  /// 0 Resonances, 1 Bonds, 2 Search.
  final int tab;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, BondsScreen(initialTab: tab));
}

class PlaylistRoute extends GoRouteData with $PlaylistRoute {
  const PlaylistRoute({required this.id});

  final String id;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, PlaylistDetailScreen(playlistId: id));
}

/// A genre from the search screen; [name] titles it (a query parameter,
/// so a link without it still opens).
class GenreRoute extends GoRouteData with $GenreRoute {
  const GenreRoute({required this.id, this.name = ''});

  final String id;
  final String name;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, GenreScreen(genreId: id, name: name));
}

class ReleaseRadarRoute extends GoRouteData with $ReleaseRadarRoute {
  const ReleaseRadarRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const ReleaseRadarScreen());
}

class TimeMachineRoute extends GoRouteData with $TimeMachineRoute {
  const TimeMachineRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const TimeMachineScreen());
}

class ListeningClockRoute extends GoRouteData with $ListeningClockRoute {
  const ListeningClockRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const ListeningClockScreen());
}

/// Full screen, over the bottom bar and the mini player.
class GuessSongRoute extends GoRouteData with $GuessSongRoute {
  const GuessSongRoute();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const GuessSongScreen());
}

/// Full screen, over the bottom bar and the mini player.
class RunModeRoute extends GoRouteData with $RunModeRoute {
  const RunModeRoute();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const RunModeScreen());
}

/// Full screen, over the bottom bar and the mini player.
class MaskCollectionRoute extends GoRouteData with $MaskCollectionRoute {
  const MaskCollectionRoute();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, const MaskCollectionScreen());
}

/// The tutorial again, from the settings; it closes when done.
class TutorialRoute extends GoRouteData with $TutorialRoute {
  const TutorialRoute();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => cyberPage(
        state,
        Builder(
          builder: (context) => OnboardingScreen(
            onComplete: () {
              if (context.canPop()) context.pop();
            },
          ),
        ),
      );
}

/// A year's (or, with [month], a month's) recap, full screen.
class WrappedRoute extends GoRouteData with $WrappedRoute {
  const WrappedRoute({required this.year, this.month});

  final int year;
  final int? month;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => CustomTransitionPage(
        key: state.pageKey,
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.normal,
        child: WrappedScreen(year: year, month: month),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
}

// --- Page transitions

CustomTransitionPage<void> fadePage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.normal,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    );

/// The app's page transition: a short fade and slide.
CustomTransitionPage<void> cyberPage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.normal,
      reverseTransitionDuration: AppMotion.normal,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// [cyberPage]'s transition for a route pushed with Navigator (E-04): the
/// screens that aren't go_router routes open like the rest of the app.
PageRouteBuilder<T> cyberRoute<T>(Widget child, {bool fullscreenDialog = false}) => PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      transitionDuration: AppMotion.normal,
      reverseTransitionDuration: AppMotion.normal,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
