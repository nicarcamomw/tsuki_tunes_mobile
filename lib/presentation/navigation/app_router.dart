import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'session_gate.dart';

/// The navigator above everything: login, onboarding, the main shell, and
/// full-screen pages (run mode, masks) pushed over the bottom bar.
final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class AppPaths {
  static const home = '/';
  static const loading = '/loading';
  static const login = '/login';
  static const onboarding = '/onboarding';
}

/// Tells the main screen when a page is pushed or popped inside it, so the
/// system back gesture knows whether it closes a page or the app.
final shellNavigatorObserver = ShellNavigatorObserver();

class ShellNavigatorObserver extends NavigatorObserver {
  VoidCallback? onNavigationChanged;

  @override
  void didPush(Route route, Route? previousRoute) => onNavigationChanged?.call();

  @override
  void didPop(Route route, Route? previousRoute) => onNavigationChanged?.call();

  @override
  void didRemove(Route route, Route? previousRoute) => onNavigationChanged?.call();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onNavigationChanged?.call();
}

/// The app's routes. The session decides the first screen: [redirect]
/// sends a signed-out user to the login, a new one to the tutorial and
/// everyone else to the main screen, keeping where a link pointed (`from`)
/// until the session is ready.
GoRouter createAppRouter(SessionGate session) => GoRouter(
      navigatorKey: rootNavigatorKey,
      refreshListenable: session,
      initialLocation: AppPaths.home,
      redirect: (context, state) => sessionRedirect(
        session.status,
        state.uri,
        guest: session.isGuest,
      ),
      routes: $appRoutes,
    );

const _gatePaths = {AppPaths.loading, AppPaths.login, AppPaths.onboarding};

/// Where [uri] should go for the session [status]; null to stay. Kept
/// apart from the router so tests can check every case.
@visibleForTesting
String? sessionRedirect(SessionStatus status, Uri uri, {bool guest = false}) {
  final path = uri.path;
  // The page a link asked for, held while the session gets ready.
  final from = uri.queryParameters['from'];
  String gate(String gatePath) {
    if (path == gatePath) return gatePath;
    final target = _gatePaths.contains(path) ? from : uri.toString();
    final keep = target != null && target != AppPaths.home;
    return keep ? Uri(path: gatePath, queryParameters: {'from': target}).toString() : gatePath;
  }

  String? stayOr(String target) => target == uri.toString() ? null : target;

  return switch (status) {
    SessionStatus.loading => stayOr(gate(AppPaths.loading)),
    SessionStatus.signedOut => stayOr(gate(AppPaths.login)),
    SessionStatus.onboarding => stayOr(gate(AppPaths.onboarding)),
    // A guest may open the login to sign in with Google.
    SessionStatus.ready when path == AppPaths.login && guest => null,
    SessionStatus.ready when _gatePaths.contains(path) => from ?? AppPaths.home,
    SessionStatus.ready => null,
  };
}
