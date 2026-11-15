import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/session_gate.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/frosted_glass.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/oni_mask_icon.dart';

/// A session that counts what the guide tells it.
class _Gate extends ChangeNotifier implements SessionGate {
  int saved = 0;
  int completed = 0;

  @override
  Future<void> saveOnboardingDone() async => saved++;
  @override
  void onboardingCompleted() => completed++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Gate gate;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gate = _Gate();
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onComplete, bool still = false}) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleProvider()),
        sessionGateProvider.overrideWith((ref) => gate),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: child!,
        ),
        home: OnboardingScreen(onComplete: onComplete),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// "Next", the page's move to its end, and the button's change.
  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('first run: four steps, each with its live demo on glass, then into the app', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.text('Marca lo que escuchas'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);
    // The title is a header for TalkBack; the demo sits on liquid glass.
    expect(tester.getSemantics(find.text('Marca lo que escuchas')), matchesSemantics(isHeader: true, label: 'Marca lo que escuchas'));
    expect(find.ancestor(of: find.byType(OniMaskIcon).first, matching: find.byType(FrostedGlass)), findsOneWidget);

    await next(tester);
    expect(find.text('Encuentra cualquier canción'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 2 de 4'), findsOneWidget);
    await next(tester);
    expect(find.text('Escúchala a tu manera'), findsOneWidget);
    await next(tester);
    expect(find.text('Despierta a los seres'), findsOneWidget);
    expect(find.text('Empezar a escuchar'), findsOneWidget);
    expect(gate.saved, 0);

    await next(tester);
    expect(gate.saved, 1);
    expect(gate.completed, 1, reason: 'the router moves on to the app');
    handle.dispose();
  });

  testWidgets('"Skip" leaves from any step, once', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Saltar'));
    await tester.tap(find.text('Saltar'), warnIfMissed: false);
    await tester.pump();
    expect(gate.saved, 1);
    expect(gate.completed, 1);
  });

  testWidgets('swiping moves between steps too', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Encuentra cualquier canción'), findsOneWidget);
  });

  testWidgets('back steps back through the guide before it leaves it', (tester) async {
    await pump(tester);
    await next(tester);
    await next(tester);
    expect(find.text('Escúchala a tu manera'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Encuentra cualquier canción'), findsOneWidget);
    expect(gate.saved, 0);
  });

  testWidgets('the tutorial from the settings: a close button, "Done", and it hands back', (tester) async {
    var closed = 0;
    await pump(tester, onComplete: () => closed++);
    expect(find.text('Saltar'), findsNothing);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(find.text('Listo'), findsOneWidget);
    await next(tester);
    expect(closed, 1);
    expect(gate.completed, 0, reason: 'the first run is long done');

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();
    expect(closed, 1, reason: 'once');
  });

  testWidgets('with less motion: each demo shows its end, still, and settles', (tester) async {
    await pump(tester, still: true);
    await tester.pumpAndSettle();
    // The library: every song marked, the album complete.
    expect(find.text('4/4'), findsOneWidget);

    await next(tester);
    await tester.pumpAndSettle();
    expect(find.text('daft punk'), findsOneWidget);
    expect(find.text('Radio del artista'), findsOneWidget);

    await next(tester);
    await tester.pumpAndSettle();
    expect(find.text('VISTA PREVIA · 30 s'), findsOneWidget);
    expect(find.text('Bajo la luna'), findsOneWidget);

    await next(tester);
    await tester.pumpAndSettle();
    expect(find.text('NIVEL 8'), findsOneWidget);
    expect(find.text('DESPERTÓ'), findsOneWidget);
  });

  testWidgets('the library demo is yours to touch: a song tapped loses or gains its mask', (tester) async {
    await pump(tester, still: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digital Love'));
    await tester.pumpAndSettle();
    expect(find.text('3/4'), findsOneWidget);
    await tester.tap(find.text('Digital Love'));
    await tester.pumpAndSettle();
    expect(find.text('4/4'), findsOneWidget);
  });

  testWidgets('moving, the library demo marks its songs one by one, then starts over', (tester) async {
    await pump(tester);
    expect(find.text('0/4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('0/4'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('0/4'), findsOneWidget, reason: 'the loop starts over');
  });

  testWidgets('every step fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 580 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleProvider()),
        sessionGateProvider.overrideWith((ref) => gate),
      ],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      if (i < 3) await next(tester);
    }
  });
}
