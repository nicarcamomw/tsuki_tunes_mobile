import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/core/theme/design_tokens.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/frosted_glass.dart';

Future<void> _pump(WidgetTester tester, Widget glass, {bool highContrast = false}) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 200, height: 60, child: glass)),
        ),
      ),
    );

void main() {
  testWidgets('what is behind shows through, blurred, under a veil that keeps white text readable', (tester) async {
    await _pump(tester, FrostedGlass(borderRadius: BorderRadius.circular(AppRadius.chip), child: const Text('hola')));
    expect(find.byType(BackdropFilter), findsOneWidget);
    // Clipped to its own shape, or the blur would cover the whole screen.
    expect(find.ancestor(of: find.byType(BackdropFilter), matching: find.byType(ClipRRect)), findsOneWidget);
    final veil = tester.widget<DecoratedBox>(find.byKey(FrostedGlass.veilKey)).decoration as BoxDecoration;
    expect(veil.color!.a, closeTo(AppGlass.fill, 0.001));

    // White text over the veil with pure white behind it still reads at AA.
    final worst = Color.alphaBlend(veil.color!, Colors.white);
    final ratio = (1.05) / (worst.computeLuminance() + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });

  testWidgets('a square bar is clipped too', (tester) async {
    await _pump(tester, const FrostedGlass(color: AppColors.surface));
    expect(find.ancestor(of: find.byType(BackdropFilter), matching: find.byType(ClipRect)), findsOneWidget);
  });

  testWidgets('with high contrast it is solid: nothing shows through', (tester) async {
    await _pump(tester, const FrostedGlass(shape: BoxShape.circle), highContrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
    final veil = tester.widget<DecoratedBox>(find.byKey(FrostedGlass.veilKey)).decoration as BoxDecoration;
    expect(veil.color!.a, 1);
  });

  testWidgets('liquid glass: light caught on the rim, a shadow under it', (tester) async {
    await _pump(tester, FrostedGlass(fill: AppGlass.clearFill, borderRadius: BorderRadius.circular(AppRadius.pill)));
    final rim = find.descendant(of: find.byType(FrostedGlass), matching: find.byType(CustomPaint));
    expect(tester.widgetList<CustomPaint>(rim).any((p) => p.foregroundPainter != null), isTrue);
    // The shadow is painted around it (only outside: under the glass it
    // would show through).
    expect(tester.widgetList<CustomPaint>(rim).any((p) => p.painter != null), isTrue);
    final veil = tester.widget<DecoratedBox>(find.byKey(FrostedGlass.veilKey)).decoration as BoxDecoration;
    expect(veil.color!.a, closeTo(AppGlass.clearFill, 0.001));
  });

  testWidgets('a glass button keeps its white icon at 3:1 over a white cover', (tester) async {
    final veil = AppColors.surface.withValues(alpha: AppGlass.buttonFill);
    final worst = Color.alphaBlend(veil, Colors.white);
    expect(1.05 / (worst.computeLuminance() + 0.05), greaterThanOrEqualTo(3));
  });

  testWidgets('faded out, it draws no blur at all', (tester) async {
    await _pump(tester, const FrostedGlass(opacity: 0));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
