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
      redirect: (context, state) => appRedirect(
        session.status,
        state.uri,
        guest: session.isGuest,
      ),
      routes: $appRoutes,
    );

/// The app's link scheme: tsukitunes://album/123, tsukitunes://artist/27,
/// tsukitunes://playlist/abc, tsukitunes://track/3135556.
const deepLinkScheme = 'tsukitunes';

/// A deep link as the app's own location: in tsukitunes://album/123 the
/// page is the URI's host ("album"), which go_router, matching on the path
/// alone, would drop. Null for anything that isn't a tsukitunes link.
@visibleForTesting
String? deepLinkLocation(Uri uri) {
  if (uri.scheme != deepLinkScheme) return null;
  final segments = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments.where((s) => s.isNotEmpty)];
  return Uri(
    path: '/${segments.join('/')}',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

/// The router's redirect: a deep link becomes the app's location first,
/// then the session decides whether it can be shown yet ([sessionRedirect]).
@visibleForTesting
String? appRedirect(SessionStatus status, Uri uri, {bool guest = false}) =>
    deepLinkLocation(uri) ?? sessionRedirect(status, uri, guest: guest);

const _gatePaths = {AppPaths.loading, AppPaths.login, AppPaths.onboarding};

/// Where [uri] should go for the session [status]; null to stay. Kept
/// apart from the router so tests can check every case.
@visibleForTesting
String? sessionRedirect(SessionStatus status, Uri uri, {bool guest = false}) {
  final path = uri.path;
  // The page a link asked for, held while the session gets ready.
  final from = uri.queryParameters['from'];
  String gate(String gatePath) {
    // Already there: stay, with the link it holds.
    if (path == gatePath) return uri.toString();
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
