import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/haptics.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/tap_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> felt;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Haptics.debugReset();
    felt = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        felt.add((call.arguments as String? ?? 'vibrate').replaceFirst('HapticFeedbackType.', ''));
      }
      return null;
    });
  });

  test('every vibration goes through Haptics, so each meaning feels the same everywhere', () {
    final direct = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            !f.path.replaceAll(r'\', '/').endsWith('presentation/widgets/haptics.dart') &&
            f.readAsStringSync().contains('HapticFeedback.'))
          f.path,
    ];
    expect(direct, isEmpty, reason: 'use Haptics.selection/tap/confirm/... instead');
  });

  test('each meaning has its own feel', () async {
    Haptics.selection();
    Haptics.tap();
    Haptics.threshold();
    Haptics.longPress();
    Haptics.confirm();
    Haptics.remove();
    await pumpEventQueue();
    expect(felt, ['selectionClick', 'lightImpact', 'lightImpact', 'mediumImpact', 'mediumImpact', 'mediumImpact']);
  });

  testWidgets('success and error are two beats', (tester) async {
    Haptics.success();
    await tester.pump(const Duration(milliseconds: 100));
    expect(felt, ['heavyImpact', 'lightImpact']);

    felt.clear();
    Haptics.error();
    await tester.pump(const Duration(milliseconds: 100));
    expect(felt, ['lightImpact', 'lightImpact']);
  });

  test('turned off, nothing vibrates; the choice is remembered', () async {
    await Haptics.setEnabled(false);
    Haptics.tap();
    Haptics.success();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(felt, isEmpty);

    Haptics.debugReset();
    expect(Haptics.enabled, isTrue);
    await Haptics.load();
    expect(Haptics.enabled, isFalse);
  });

  testWidgets('TapScale taps with the feel it is given, and long presses', (tester) async {
    var taps = 0, holds = 0;
    Widget scale({VoidCallback? haptic = Haptics.tap}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: TapScale(
              haptic: haptic,
              onTap: () => taps++,
              onLongPress: () => holds++,
              child: const SizedBox.square(dimension: 60),
            ),
          ),
        );

    await tester.pumpWidget(scale());
    await tester.tap(find.byType(TapScale));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(felt, ['lightImpact']);

    felt.clear();
    await tester.pumpWidget(scale(haptic: Haptics.selection));
    await tester.tap(find.byType(TapScale));
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(felt, ['selectionClick']);

    felt.clear();
    await tester.pumpWidget(scale(haptic: null));
    await tester.tap(find.byType(TapScale));
    await tester.pumpAndSettle();
    expect(taps, 3);
    expect(felt, isEmpty);

    felt.clear();
    await tester.longPress(find.byType(TapScale));
    await tester.pumpAndSettle();
    expect(holds, 1);
    expect(felt, ['mediumImpact']);
  });
}
