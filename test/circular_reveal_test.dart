import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/circular_reveal.dart';

// The gate the login and the app open through: a circle out of the mask
// while it opens, nothing at all once open (no clip, no scale, the same
// widgets so the page isn't rebuilt).
void main() {
  testWidgets('clips and scales while it opens, then leaves the page alone', (tester) async {
    final opening = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 750));
    addTearDown(opening.dispose);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: CircularReveal(
        animation: opening,
        origin: const Alignment(0, -0.4),
        child: Builder(builder: (_) {
          builds++;
          return const ColoredBox(color: Colors.black, child: SizedBox.expand());
        }),
      ),
    ));
    ClipPath clip() => tester.widget<ClipPath>(find.byType(ClipPath));
    double scale() => tester.widget<Transform>(find.byType(Transform).last).transform.getMaxScaleOnAxis();

    opening.value = 0.5;
    await tester.pump();
    expect(clip().clipBehavior, Clip.antiAlias);
    expect(scale(), greaterThan(1));

    opening.value = 1;
    await tester.pump();
    expect(clip().clipBehavior, Clip.none);
    expect(scale(), 1);
    expect(builds, 1, reason: 'the page under it is built once');
  });
}
