import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/marquee_text.dart';

// Perf: a title that slides costs nothing while it rests. The old marquees
// ran a ticker through their pauses forever, so a long song title kept the
// whole app redrawing 60 times a second.

Widget _box(String text, {double width = 120, bool still = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(width: width, child: MarqueeText(text, style: const TextStyle(fontSize: 14))),
        ),
      ),
    );

double _offset(WidgetTester tester) {
  final t = tester.widgetList<Transform>(find.descendant(of: find.byType(MarqueeText), matching: find.byType(Transform)));
  return t.isEmpty ? 0 : t.first.transform.getTranslation().x;
}

void main() {
  testWidgets('a title that fits never animates', (tester) async {
    await tester.pumpWidget(_box('Hoy', width: 300));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('a long title rests without frames, slides, rests, comes back', (tester) async {
    await tester.pumpWidget(_box('Una canción con un título larguísimo que no cabe'));
    await tester.pump();
    // The first rest: a timer, no ticker.
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.hasRunningAnimations, isFalse, reason: 'resting asks for no frames');
    expect(_offset(tester), 0);
    // Then it slides.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    expect(_offset(tester), lessThan(0));
    // Far end, resting again: no frames.
    await tester.pump(const Duration(seconds: 9));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with reduce motion it stays put', (tester) async {
    await tester.pumpWidget(_box('Una canción con un título larguísimo que no cabe', still: true));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(Transform), findsNothing);
  });
}
