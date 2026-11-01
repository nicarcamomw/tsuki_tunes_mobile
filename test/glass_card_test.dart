import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/glass_card.dart';

void main() {
  testWidgets('blots bloom once, then the card asks for no more frames', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GlassCard(color: Colors.purple, child: SizedBox(height: 60, width: 300)),
    ));
    expect(tester.binding.transientCallbackCount, 1, reason: 'blooming');
    await tester.pump(GlassCard.bloomDuration);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0, reason: 'still after the bloom');
  });

  testWidgets('reduced motion shows the blots right away', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: GlassCard(color: Colors.cyan, child: SizedBox(height: 60, width: 300)),
      ),
    ));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
