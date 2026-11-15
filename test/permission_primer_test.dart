import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/battery_guide.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/permission_primer.dart';

import 'helpers/test_scope.dart';

/// Android limits Tsuki's battery until asked; records what was asked.
class _FakeGuide implements BatteryGuide {
  bool limited = true;
  bool asked = false;
  int systemDialogs = 0;

  @override
  Future<bool> shouldOfferBackground() async => limited && !asked;

  @override
  Future<void> askToRunInBackground() async {
    asked = true;
    systemDialogs++;
  }

  @override
  Future<void> declineBackground() async => asked = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeGuide guide;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    guide = _FakeGuide();
  });

  Future<BuildContext> app(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(TestScope(
      overrides: [batteryGuideProvider.overrideWithValue(guide)],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }))),
    ));
    return ctx;
  }

  testWidgets('the reason comes first; "Allow" says yes, "Not now" no', (tester) async {
    final ctx = await app(tester);

    final allowed = PermissionPrimer.notifications(ctx);
    await tester.pumpAndSettle();
    expect(find.text('¿Te avisamos cuando salga algo nuevo?'), findsOneWidget);
    await tester.tap(find.text('Permitir'));
    await tester.pumpAndSettle();
    expect(await allowed, isTrue);

    final declined = PermissionPrimer.notifications(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(await declined, isFalse);
  });

  testWidgets('Android\'s battery dialog only after a yes, and only once', (tester) async {
    final ctx = await app(tester);

    final offer = PermissionPrimer.offerBackgroundIfNeeded(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Que la música no se corte'), findsOneWidget);
    expect(guide.systemDialogs, 0, reason: 'nothing from Android before the user reads why');
    await tester.tap(find.text('Permitir'));
    await tester.pumpAndSettle();
    await offer;
    expect(guide.systemDialogs, 1);

    // Asked: never offered again.
    await PermissionPrimer.offerBackgroundIfNeeded(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Que la música no se corte'), findsNothing);
  });

  testWidgets('"Not now" asks Android nothing and isn\'t offered again', (tester) async {
    final ctx = await app(tester);

    final offer = PermissionPrimer.offerBackgroundIfNeeded(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await offer;
    expect(guide.systemDialogs, 0);
    expect(await guide.shouldOfferBackground(), isFalse);
  });

  testWidgets('nothing is offered when Android already lets Tsuki run', (tester) async {
    guide.limited = false;
    final ctx = await app(tester);

    await PermissionPrimer.offerBackgroundIfNeeded(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
  });

  testWidgets('the sheet meets the touch and label guidelines', (tester) async {
    final ctx = await app(tester);
    unawaited(PermissionPrimer.notifications(ctx));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('a small phone with large text still reaches both buttons', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 560 * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ctx = await app(tester);

    final answer = PermissionPrimer.notifications(ctx);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('notifications: the Radar\'s own notice acted out, the question as a header, three short lines', (tester) async {
    final handle = tester.ensureSemantics();
    final ctx = await app(tester);
    unawaited(PermissionPrimer.notifications(ctx));
    await tester.pumpAndSettle();

    // What a notice from the Radar looks like, word for word.
    expect(find.text('Daft Punk sacó un álbum nuevo'), findsOneWidget);
    expect(find.text('Random Access Memories'), findsOneWidget);
    expect(tester.getSemantics(find.text('¿Te avisamos cuando salga algo nuevo?')),
        matchesSemantics(isHeader: true, label: '¿Te avisamos cuando salga algo nuevo?'));
    expect(find.text('Solo música nueva de los artistas que sigues'), findsOneWidget);
    expect(find.text('Nada de publicidad'), findsOneWidget);
    expect(find.text('Lo apagas cuando quieras en el Radar'), findsOneWidget);
    // The scene is decoration: TalkBack reads the question and the lines.
    expect(find.bySemanticsLabel('Daft Punk sacó un álbum nuevo'), findsNothing);
    handle.dispose();
  });

  testWidgets('background: the phone locks and the song plays on; three lines', (tester) async {
    final ctx = await app(tester);
    unawaited(PermissionPrimer.offerBackgroundIfNeeded(ctx));
    await tester.pumpAndSettle();
    expect(find.text('23:41'), findsOneWidget);
    expect(find.text('Android puede cerrar Tsuki al bloquear el teléfono'), findsOneWidget);
    expect(find.text('Así la música sigue con la pantalla apagada'), findsOneWidget);
    expect(find.text('Te lo preguntamos una sola vez'), findsOneWidget);
  });

  testWidgets('the scene plays once and settles; with less motion it starts at its end', (tester) async {
    final ctx = await app(tester);
    unawaited(PermissionPrimer.notifications(ctx));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Early on, the lines haven't risen yet.
    final early = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('Nada de publicidad'), matching: find.byType(FadeTransition)).first);
    expect(early.opacity.value, lessThan(0.1));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    Navigator.of(ctx, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    unawaited(PermissionPrimer.notifications(ctx));
    await tester.pump();
    await tester.pump();
    final still = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('Nada de publicidad'), matching: find.byType(FadeTransition)).first);
    expect(still.opacity.value, 1);
  });
}
