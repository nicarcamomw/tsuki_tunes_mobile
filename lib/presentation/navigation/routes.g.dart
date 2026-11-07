// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $loadingRoute,
  $loginRoute,
  $onboardingRoute,
  $mainShellRoute,
];

RouteBase get $loadingRoute => GoRouteData.$route(
  path: '/loading',
  hasOverriddenOnExit: false,
  factory: $LoadingRoute._fromState,
);

mixin $LoadingRoute on GoRouteData {
  static LoadingRoute _fromState(GoRouterState state) => const LoadingRoute();

  @override
  String get location => GoRouteData.$location('/loading');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $loginRoute => GoRouteData.$route(
  path: '/login',
  hasOverriddenOnExit: false,
  factory: $LoginRoute._fromState,
);

mixin $LoginRoute on GoRouteData {
  static LoginRoute _fromState(GoRouterState state) => const LoginRoute();

  @override
  String get location => GoRouteData.$location('/login');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $onboardingRoute => GoRouteData.$route(
  path: '/onboarding',
  hasOverriddenOnExit: false,
  factory: $OnboardingRoute._fromState,
);

mixin $OnboardingRoute on GoRouteData {
  static OnboardingRoute _fromState(GoRouterState state) =>
      const OnboardingRoute();

  @override
  String get location => GoRouteData.$location('/onboarding');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $mainShellRoute => ShellRouteData.$route(
  navigatorKey: MainShellRoute.$navigatorKey,
  observers: MainShellRoute.$observers,
  factory: $MainShellRouteExtension._fromState,
  routes: [
    GoRouteData.$route(
      path: '/',
      hasOverriddenOnExit: false,
      factory: $HomeRoute._fromState,
      routes: [
        GoRouteData.$route(
          path: 'album/:id',
          hasOverriddenOnExit: false,
          factory: $AlbumRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'artist/:id',
          hasOverriddenOnExit: false,
          factory: $ArtistRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'albums',
              hasOverriddenOnExit: false,
              factory: $ArtistDiscographyRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'rabbit-hole',
              hasOverriddenOnExit: false,
              factory: $RabbitHoleRoute._fromState,
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'playlist/:id',
          hasOverriddenOnExit: false,
          factory: $PlaylistRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'track/:id',
          hasOverriddenOnExit: false,
          factory: $TrackRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'user/:uid',
          hasOverriddenOnExit: false,
          factory: $UserProfileRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'bonds',
          hasOverriddenOnExit: false,
          factory: $BondsRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'discover',
          hasOverriddenOnExit: false,
          factory: $DiscoveryRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'import-spotify',
          hasOverriddenOnExit: false,
          factory: $SpotifyImportRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'shared/:id',
          hasOverriddenOnExit: false,
          factory: $SharedPlaylistRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'party',
          hasOverriddenOnExit: false,
          factory: $PartyRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'radar',
          hasOverriddenOnExit: false,
          factory: $ReleaseRadarRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'time-machine',
          hasOverriddenOnExit: false,
          factory: $TimeMachineRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'listening-clock',
          hasOverriddenOnExit: false,
          factory: $ListeningClockRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'guess',
          hasOverriddenOnExit: false,
          parentNavigatorKey: GuessSongRoute.$parentNavigatorKey,
          factory: $GuessSongRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'run',
          hasOverriddenOnExit: false,
          parentNavigatorKey: RunModeRoute.$parentNavigatorKey,
          factory: $RunModeRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'masks',
          hasOverriddenOnExit: false,
          parentNavigatorKey: MaskCollectionRoute.$parentNavigatorKey,
          factory: $MaskCollectionRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'wrapped/:year',
          hasOverriddenOnExit: false,
          parentNavigatorKey: WrappedRoute.$parentNavigatorKey,
          factory: $WrappedRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'tutorial',
          hasOverriddenOnExit: false,
          parentNavigatorKey: TutorialRoute.$parentNavigatorKey,
          factory: $TutorialRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'genre/:id',
          hasOverriddenOnExit: false,
          factory: $GenreRoute._fromState,
        ),
      ],
    ),
  ],
);

extension $MainShellRouteExtension on MainShellRoute {
  static MainShellRoute _fromState(GoRouterState state) =>
      const MainShellRoute();
}

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AlbumRoute on GoRouteData {
  static AlbumRoute _fromState(GoRouterState state) => AlbumRoute(
    id: state.pathParameters['id']!,
    $extra: state.extra as Album?,
  );

  AlbumRoute get _self => this as AlbumRoute;

  @override
  String get location =>
      GoRouteData.$location('/album/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin $ArtistRoute on GoRouteData {
  static ArtistRoute _fromState(GoRouterState state) => ArtistRoute(
    id: state.pathParameters['id']!,
    $extra: state.extra as Artist?,
  );

  ArtistRoute get _self => this as ArtistRoute;

  @override
  String get location =>
      GoRouteData.$location('/artist/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin $ArtistDiscographyRoute on GoRouteData {
  static ArtistDiscographyRoute _fromState(GoRouterState state) =>
      ArtistDiscographyRoute(
        id: state.pathParameters['id']!,
        filter: state.uri.queryParameters['filter'] ?? 'all',
        $extra: state.extra as DiscographyArgs,
      );

  ArtistDiscographyRoute get _self => this as ArtistDiscographyRoute;

  @override
  String get location => GoRouteData.$location(
    '/artist/${Uri.encodeComponent(_self.id)}/albums',
    queryParams: {if (_self.filter != 'all') 'filter': _self.filter},
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin $RabbitHoleRoute on GoRouteData {
  static RabbitHoleRoute _fromState(GoRouterState state) => RabbitHoleRoute(
    id: state.pathParameters['id']!,
    $extra: state.extra as Artist?,
  );

  RabbitHoleRoute get _self => this as RabbitHoleRoute;

  @override
  String get location => GoRouteData.$location(
    '/artist/${Uri.encodeComponent(_self.id)}/rabbit-hole',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin $PlaylistRoute on GoRouteData {
  static PlaylistRoute _fromState(GoRouterState state) =>
      PlaylistRoute(id: state.pathParameters['id']!);

  PlaylistRoute get _self => this as PlaylistRoute;

  @override
  String get location =>
      GoRouteData.$location('/playlist/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TrackRoute on GoRouteData {
  static TrackRoute _fromState(GoRouterState state) =>
      TrackRoute(id: state.pathParameters['id']!);

  TrackRoute get _self => this as TrackRoute;

  @override
  String get location =>
      GoRouteData.$location('/track/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $UserProfileRoute on GoRouteData {
  static UserProfileRoute _fromState(GoRouterState state) =>
      UserProfileRoute(uid: state.pathParameters['uid']!);

  UserProfileRoute get _self => this as UserProfileRoute;

  @override
  String get location =>
      GoRouteData.$location('/user/${Uri.encodeComponent(_self.uid)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $BondsRoute on GoRouteData {
  static BondsRoute _fromState(GoRouterState state) => BondsRoute(
    tab: _$convertMapValue('tab', state.uri.queryParameters, int.parse) ?? 0,
  );

  BondsRoute get _self => this as BondsRoute;

  @override
  String get location => GoRouteData.$location(
    '/bonds',
    queryParams: {if (_self.tab != 0) 'tab': _self.tab.toString()},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DiscoveryRoute on GoRouteData {
  static DiscoveryRoute _fromState(GoRouterState state) =>
      const DiscoveryRoute();

  @override
  String get location => GoRouteData.$location('/discover');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SpotifyImportRoute on GoRouteData {
  static SpotifyImportRoute _fromState(GoRouterState state) =>
      const SpotifyImportRoute();

  @override
  String get location => GoRouteData.$location('/import-spotify');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SharedPlaylistRoute on GoRouteData {
  static SharedPlaylistRoute _fromState(GoRouterState state) =>
      SharedPlaylistRoute(id: state.pathParameters['id']!);

  SharedPlaylistRoute get _self => this as SharedPlaylistRoute;

  @override
  String get location =>
      GoRouteData.$location('/shared/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PartyRoute on GoRouteData {
  static PartyRoute _fromState(GoRouterState state) => const PartyRoute();

  @override
  String get location => GoRouteData.$location('/party');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ReleaseRadarRoute on GoRouteData {
  static ReleaseRadarRoute _fromState(GoRouterState state) =>
      const ReleaseRadarRoute();

  @override
  String get location => GoRouteData.$location('/radar');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TimeMachineRoute on GoRouteData {
  static TimeMachineRoute _fromState(GoRouterState state) =>
      const TimeMachineRoute();

  @override
  String get location => GoRouteData.$location('/time-machine');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ListeningClockRoute on GoRouteData {
  static ListeningClockRoute _fromState(GoRouterState state) =>
      const ListeningClockRoute();

  @override
  String get location => GoRouteData.$location('/listening-clock');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $GuessSongRoute on GoRouteData {
  static GuessSongRoute _fromState(GoRouterState state) =>
      const GuessSongRoute();

  @override
  String get location => GoRouteData.$location('/guess');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RunModeRoute on GoRouteData {
  static RunModeRoute _fromState(GoRouterState state) => const RunModeRoute();

  @override
  String get location => GoRouteData.$location('/run');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MaskCollectionRoute on GoRouteData {
  static MaskCollectionRoute _fromState(GoRouterState state) =>
      const MaskCollectionRoute();

  @override
  String get location => GoRouteData.$location('/masks');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WrappedRoute on GoRouteData {
  static WrappedRoute _fromState(GoRouterState state) => WrappedRoute(
    year: int.parse(state.pathParameters['year']!),
    month: _$convertMapValue('month', state.uri.queryParameters, int.tryParse),
  );

  WrappedRoute get _self => this as WrappedRoute;

  @override
  String get location => GoRouteData.$location(
    '/wrapped/${Uri.encodeComponent(_self.year.toString())}',
    queryParams: {if (_self.month != null) 'month': _self.month!.toString()},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TutorialRoute on GoRouteData {
  static TutorialRoute _fromState(GoRouterState state) => const TutorialRoute();

  @override
  String get location => GoRouteData.$location('/tutorial');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $GenreRoute on GoRouteData {
  static GenreRoute _fromState(GoRouterState state) => GenreRoute(
    id: state.pathParameters['id']!,
    name: state.uri.queryParameters['name'] ?? '',
  );

  GenreRoute get _self => this as GenreRoute;

  @override
  String get location => GoRouteData.$location(
    '/genre/${Uri.encodeComponent(_self.id)}',
    queryParams: {if (_self.name != '') 'name': _self.name},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}
