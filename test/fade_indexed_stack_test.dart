import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/fade_indexed_stack.dart';

/// A tab that counts its taps, to see it keep its state.
class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(onPressed: () => setState(() => taps++), child: Text('${widget.name} $taps')),
      );
}

void main() {
  Future<void> pump(WidgetTester tester, int index) => tester.pumpWidget(MaterialApp(
        home: FadeIndexedStack(index: index, children: const [_Counter('A'), _Counter('B')]),
      ));

  double opacityOf(WidgetTester tester, String text) {
    final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.text(text, skipOffstage: false), matching: find.byType(FadeTransition)).first);
    return fade.opacity.value;
  }

  bool offstage(WidgetTester tester, String text) => tester
      .widget<Offstage>(find.ancestor(of: find.text(text, skipOffstage: false), matching: find.byType(Offstage)).first)
      .offstage;

  testWidgets('changing tabs: the old one goes at once, only the new one fades in (one layer, not two)', (tester) async {
    await pump(tester, 0);
    await pump(tester, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(offstage(tester, 'A 0'), isTrue, reason: 'no cross-fade of two whole screens');
    expect(opacityOf(tester, 'B 0'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'B 0'), 1);
  });

  testWidgets('a tab keeps its state while hidden', (tester) async {
    await pump(tester, 0);
    await tester.tap(find.text('A 0'));
    await tester.pump();
    await pump(tester, 1);
    await tester.pumpAndSettle();
    await pump(tester, 0);
    await tester.pumpAndSettle();
    expect(find.text('A 1'), findsOneWidget);
  });

  testWidgets('hidden tabs are muted: their animations don\'t ask for frames', (tester) async {
    await pump(tester, 1);
    await tester.pumpAndSettle();
    final hidden = tester.element(find.text('A 0', skipOffstage: false));
    expect(TickerMode.valuesOf(hidden).enabled, isFalse);
  });
}
