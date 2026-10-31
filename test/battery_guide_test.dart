import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/playback_error.dart';
import 'package:tsuki_tunes_mobile/services/battery_guide.dart';
import 'package:tsuki_tunes_mobile/widgets/battery_guide_sheet.dart';
import 'helpers/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('phone maker', () {
    test('makers that freeze background apps, with their sister brands', () {
      expect(batteryFamilyFor('HONOR', 'HONOR'), BatteryFamily.honor);
      expect(batteryFamilyFor('HUAWEI', 'HUAWEI'), BatteryFamily.honor);
      expect(batteryFamilyFor('Xiaomi', 'Redmi'), BatteryFamily.xiaomi);
      expect(batteryFamilyFor('Xiaomi', 'POCO'), BatteryFamily.xiaomi);
      expect(batteryFamilyFor('OPPO', 'OPPO'), BatteryFamily.oppo);
      expect(batteryFamilyFor('realme', 'realme'), BatteryFamily.oppo);
      expect(batteryFamilyFor('OnePlus', 'OnePlus'), BatteryFamily.oppo);
    });

    test('other makers get no guide', () {
      expect(batteryFamilyFor('Google', 'google'), isNull);
      expect(batteryFamilyFor('samsung', 'samsung'), isNull);
      expect(batteryFamilyFor('motorola', 'motorola'), isNull);
      expect(batteryFamilyFor('', ''), isNull);
    });
  });

  group('when the guide is offered', () {
    final guide = BatteryGuide.instance;
    tearDown(() => guide.setForTesting());

    test('only when Spotify could not start, on those phones', () {
      guide.setForTesting(family: BatteryFamily.xiaomi);
      expect(guide.offerFor(SpotifyFallbackReason.openApp), isTrue);
      // The song not being on Spotify has nothing to do with the battery.
      expect(guide.offerFor(SpotifyFallbackReason.trackUnavailable), isFalse);
      expect(guide.offerFor(null), isFalse);
    });

    test('never on other phones', () {
      guide.setForTesting();
      expect(guide.offerFor(SpotifyFallbackReason.openApp), isFalse);
    });

    test('never again once turned off', () async {
      SharedPreferences.setMockInitialValues({});
      guide.setForTesting(family: BatteryFamily.honor);
      await guide.dismiss();
      expect(guide.offerFor(SpotifyFallbackReason.openApp), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('battery_guide_dismissed'), isTrue);
    });
  });

  group('the guide', () {
    Future<void> pumpGuide(WidgetTester tester, BatteryFamily family) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(TestScope(
        child: MaterialApp(
          home: Scaffold(
            body: BatteryGuideSheet(
              family: family,
              makerName: 'Redmi',
              controller: ScrollController(),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('shows the steps for the phone maker', (tester) async {
      await pumpGuide(tester, BatteryFamily.xiaomi);
      expect(find.textContaining('Redmi'), findsOneWidget);
      expect(find.textContaining('Sin restricciones'), findsOneWidget);
      expect(find.textContaining('Inicio automático'), findsOneWidget);
      expect(find.text('ABRIR AJUSTES DE SPOTIFY'), findsOneWidget);
      expect(find.text('No volver a mostrar'), findsOneWidget);
    });

    testWidgets('each maker gets its own steps', (tester) async {
      await pumpGuide(tester, BatteryFamily.honor);
      expect(find.textContaining('Gestionar manualmente'), findsOneWidget);

      await pumpGuide(tester, BatteryFamily.oppo);
      expect(find.textContaining('Permitir actividad en segundo plano'), findsOneWidget);
    });
  });
}
