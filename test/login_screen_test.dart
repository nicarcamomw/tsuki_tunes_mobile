import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/auth_error.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/loading_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/login/login_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/auth_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/frosted_glass.dart';

/// An account the test answers for.
class _Auth extends ChangeNotifier implements AuthProvider {
  Completer<bool> next = Completer<bool>();
  bool cancelled = false;
  AuthError? error;
  Duration throttle = Duration.zero;
  bool guest = false;

  @override
  Future<bool> loginWithGoogle() => next.future;
  @override
  bool get wasCancelled => cancelled;
  @override
  AuthError? get authError => error;
  @override
  Duration get loginThrottleRemaining => throttle;
  @override
  bool get isLoginThrottled => throttle > Duration.zero;
  @override
  bool get isGuest => guest;
  @override
  String? get uid => null;
  @override
  Future<void> loginAsGuest() async => guest = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _Auth();
  });

  Future<void> pump(WidgetTester tester, {bool online = true}) async {
    // Made in the test's own (fake) time, or its answer never arrives.
    auth.next = Completer<bool>();
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/login', routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    ]);
    await http.runWithClient(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleProvider()),
          authProvider.overrideWith((ref) => auth),
          isOnlineProvider.overrideWithValue(online),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(LoginScreen.intro);
    }, () => MockClient((_) => Completer<http.Response>().future));
  }

  testWidgets('the entrance\'s night and mask, the name, and the ways in on glass', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final mask = tester.widget<Image>(find.byType(Image).first);
    expect((mask.image as AssetImage).assetName, LoadingScreen.maskAsset);
    expect(find.bySemanticsLabel('Tsuki Tunes'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Entrar como observador'), findsOneWidget);
    expect(find.text('Términos'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    // The ways in sit on liquid glass.
    expect(find.ancestor(of: find.text('Continuar con Google'), matching: find.byType(FrostedGlass)), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Continuar con Google')), matchesSemantics(isButton: true, isEnabled: true, hasEnabledState: true, hasTapAction: true, label: 'Continuar con Google'));
    handle.dispose();
  });

  testWidgets('offline: Google waits, the panel says why, the observer can still come in', (tester) async {
    await pump(tester, online: false);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    await tester.pump();
    expect(auth.next.isCompleted, isFalse);
    expect(find.text('Ingresando…'), findsNothing);
  });

  testWidgets('a failed sign-in says so in place and offers to try again; a cancelled one says nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(find.text('Ingresando…'), findsOneWidget);
    auth.next.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Error al conectar con Google'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    auth
      ..next = Completer<bool>()
      ..cancelled = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    auth.next.complete(false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Error al conectar'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('too many tries: a countdown, and Google waits it out', (tester) async {
    auth.throttle = const Duration(seconds: 12);
    await pump(tester);
    expect(find.text('Demasiados intentos. Vuelve a intentar en 12 s.'), findsOneWidget);
    auth.throttle = Duration.zero;
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('signed in: the mask blooms and the app opens', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    auth.next.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the observer comes in as a guest', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Entrar como observador'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(auth.guest, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('with less motion asked for, everything holds still', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    expect(find.text('Continuar con Google'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
