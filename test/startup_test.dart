import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/data/datasources/firebase_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/playlist_repository_impl.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/session_gate.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/loading_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/auth_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';

/// Firebase that never answers.
class _Hanging implements FirebaseService {
  @override
  Future<void> initialize() => Completer<void>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed in, the account known.
class _SignedIn extends ChangeNotifier implements AuthProvider {
  @override
  bool get loading => false;
  @override
  bool get isLoggedIn => true;
  @override
  bool get isGuest => true; // local playlists only: no Firestore in tests
  @override
  String? get uid => 'u1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The phone's storage failing to answer.
class _BrokenStorage implements StorageService {
  @override
  Future<bool> hasCompletedOnboarding() async => throw StateError('disk');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists implements PlaylistRepositoryImpl {
  @override
  Future<void> initLocalOnly(String uid) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A session the test moves on by hand.
class _Gate extends ChangeNotifier implements SessionGate {
  SessionStatus _status = SessionStatus.loading;
  @override
  SessionStatus get status => _status;
  void ready() {
    _status = SessionStatus.ready;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpLoading(WidgetTester tester, {bool still = false}) => tester.pumpWidget(
        ProviderScope(
          overrides: [localeProvider.overrideWith((ref) => LocaleProvider())],
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: const MaterialApp(home: LoadingScreen()),
          ),
        ),
      );

  testWidgets('the loading screen carries on the splash: its night, the mask, said as loading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLoading(tester);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppColors.splash);
    final mask = tester.widget<Image>(find.byType(Image));
    expect((mask.image as AssetImage).assetName, 'assets/images/cyber_oni_mask.png');
    expect(mask.width, LoadingScreen.maskWidth);
    // At the screen's centre, where the splash left it.
    final screen = tester.getSize(find.byType(Scaffold));
    final centre = tester.getCenter(find.byType(Image));
    // The image is nudged so its mask (6% right of the image's middle) is centred.
    expect(centre.dx, closeTo(screen.width / 2 + LoadingScreen.maskNudge, 1));
    expect(centre.dy, closeTo(screen.height / 2, 1));
    // The line stays clear below it.
    expect(tester.getTopLeft(find.text('Despertando la luna…')).dy, greaterThan(tester.getBottomLeft(find.byType(Image)).dy));
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);

    // The line under the mask only once waking takes a moment.
    double lineOpacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.text('Despertando la luna…'), matching: find.byType(AnimatedOpacity)))
        .opacity;
    expect(lineOpacity(), 0);
    await tester.pump(LoadingScreen.patience + const Duration(milliseconds: 50));
    expect(lineOpacity(), 1);
    handle.dispose();
  });

  testWidgets('ready, the mask blooms into the next screen', (tester) async {
    final gate = _Gate();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleProvider()),
          sessionGateProvider.overrideWith((ref) => gate),
        ],
        child: const MaterialApp(home: LoadingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    double maskOpacity() =>
        tester.widget<Opacity>(find.ancestor(of: find.byType(Image).last, matching: find.byType(Opacity)).first).opacity;
    expect(maskOpacity(), 1);
    gate.ready();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(maskOpacity(), lessThan(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(maskOpacity(), 0);
  });

  testWidgets('with less motion asked for, the mask holds still', (tester) async {
    await pumpLoading(tester, still: true);
    await tester.pump(LoadingScreen.patience);
    // Nothing repeats: it settles.
    await tester.pumpAndSettle();
    expect(find.byType(LoadingScreen), findsOneWidget);
  });

  test('Android\'s splash and the first frame share one night, and the logo is sized', () {
    final colors = File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final hex = RegExp(r'name="splash_background">#([0-9A-Fa-f]{6})<').firstMatch(colors)![1]!;
    expect(Color(int.parse('FF$hex', radix: 16)), AppColors.splash);
    for (final dir in ['drawable', 'drawable-v21']) {
      final launch = File('android/app/src/main/res/$dir/launch_background.xml').readAsStringSync();
      // A 1024 px logo drawn at its own size was a giant crop of the mask.
      expect(launch, contains('android:width="288dp"'), reason: dir);
      expect(launch, contains('android:height="288dp"'), reason: dir);
      // With the glow lit, as Android 12's animated splash ends.
      expect(launch, contains('@drawable/splash_glow_09'), reason: dir);
    }
    // Android 12+: the glow lights up, frame by frame, and every frame exists.
    for (final dir in ['values-v31', 'values-night-v31']) {
      final styles = File('android/app/src/main/res/$dir/styles.xml').readAsStringSync();
      expect(styles, contains('@drawable/splash_anim'), reason: dir);
      expect(styles, contains('windowSplashScreenAnimationDuration'), reason: dir);
    }
    final anim = File('android/app/src/main/res/drawable/splash_anim.xml').readAsStringSync();
    for (final m in RegExp(r'@drawable/(splash_glow_\d+)').allMatches(anim)) {
      expect(File('android/app/src/main/res/drawable/${m[1]}.webp').existsSync(), isTrue, reason: m[1]);
    }
  });

  test('a storage that fails to answer never leaves the app on the loading screen', () async {
    final gate = SessionGate(
      auth: _SignedIn(),
      library: LibraryRepositoryImpl(),
      playlists: _Playlists(),
      storage: _BrokenStorage(),
    );
    expect(gate.status, SessionStatus.loading);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(gate.status, SessionStatus.ready);
    gate.dispose();
  });

  testWidgets('Firebase not answering: after a while the app stops waiting', (tester) async {
    final auth = AuthProvider(firebase: _Hanging());
    await tester.pump(const Duration(seconds: 1));
    expect(auth.loading, isTrue);
    await tester.pump(AuthProvider.startPatience);
    expect(auth.loading, isFalse);
    expect(auth.isLoggedIn, isFalse);
    auth.dispose();
  });
}
