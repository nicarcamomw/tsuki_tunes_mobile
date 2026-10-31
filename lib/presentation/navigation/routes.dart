import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/guess_song_screen.dart';
import '../screens/listening_clock_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/mask_collection_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../screens/release_radar_screen.dart';
import '../screens/run_mode_screen.dart';
import '../screens/time_machine_screen.dart';
import '../screens/wrapped_screen.dart';
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
        TypedGoRoute<PlaylistRoute>(path: 'playlist/:id'),
        TypedGoRoute<ReleaseRadarRoute>(path: 'radar'),
        TypedGoRoute<TimeMachineRoute>(path: 'time-machine'),
        TypedGoRoute<ListeningClockRoute>(path: 'listening-clock'),
        TypedGoRoute<GuessSongRoute>(path: 'guess'),
        TypedGoRoute<RunModeRoute>(path: 'run'),
        TypedGoRoute<MaskCollectionRoute>(path: 'masks'),
        TypedGoRoute<WrappedRoute>(path: 'wrapped/:year'),
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

class PlaylistRoute extends GoRouteData with $PlaylistRoute {
  const PlaylistRoute({required this.id});

  final String id;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      cyberPage(state, PlaylistDetailScreen(playlistId: id));
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

class GuessSongRoute extends GoRouteData with $GuessSongRoute {
  const GuessSongRoute();

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

/// A year's (or, with [month], a month's) recap, full screen.
class WrappedRoute extends GoRouteData with $WrappedRoute {
  const WrappedRoute({required this.year, this.month});

  final int year;
  final int? month;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) => CustomTransitionPage(
        key: state.pageKey,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 260),
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
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    );

/// The app's page transition (CyberPageRoute's): a short fade and slide.
CustomTransitionPage<void> cyberPage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
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
