import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/moon_loader.dart';

// P-08: the loading moon turns through its phases, and holds still when
// less motion is asked for.

void main() {
  testWidgets('it animates, and is still with reduce motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: MoonLoader())));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Center(child: MoonLoader())),
    ));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('decoration unless it is given a label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: Center(child: MoonLoader(semanticLabel: 'Cargando'))));
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
