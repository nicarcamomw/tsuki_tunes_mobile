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
          path: 'playlist/:id',
          hasOverriddenOnExit: false,
          factory: $PlaylistRoute._fromState,
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

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}
