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
}
