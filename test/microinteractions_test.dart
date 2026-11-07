import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/pop_on_change.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/tap_scale.dart';

Widget _frame(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
    );

double _scaleOf(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  group('PopOnChange', () {
    Widget pop(bool on, {bool reduceMotion = false}) =>
        _frame(PopOnChange(value: on, child: const SizedBox.square(dimension: 20)), reduceMotion: reduceMotion);

    testWidgets('pops when its value flips, then settles', (tester) async {
      await tester.pumpWidget(pop(false));
      expect(_scaleOf(tester), 1.0);

      await tester.pumpWidget(pop(true));
      await tester.pump(PopOnChange.duration * 0.3);
      expect(_scaleOf(tester), closeTo(1.22, 0.01));

      await tester.pumpAndSettle();
      expect(_scaleOf(tester), 1.0);
    });

    testWidgets('nothing on the first build or an unchanged rebuild', (tester) async {
      await tester.pumpWidget(pop(true));
      await tester.pumpWidget(pop(true));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('reduced motion: no pop', (tester) async {
      await tester.pumpWidget(pop(false, reduceMotion: true));
      await tester.pumpWidget(pop(true, reduceMotion: true));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  testWidgets('TapScale acts on release, without waiting for its animation', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_frame(TapScale(onTap: () => taps++, child: const SizedBox.square(dimension: 60))));

    await tester.tap(find.byType(TapScale));
    // Same frame as the release: the action already ran.
    expect(taps, 1);
    // The press still plays out and springs back.
    await tester.pumpAndSettle();
    final scale = tester.widget<Transform>(
      find.descendant(of: find.byType(TapScale), matching: find.byType(Transform)).first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
  });
}
