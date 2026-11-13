import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/fade_indexed_stack.dart';

/// A tab with an endless animation (like the orb or a visualizer) that
/// counts the frames it gets.
class _Spinner extends StatefulWidget {
  const _Spinner(this.ticks);
  final List<int> ticks;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() => widget.ticks[0]++)
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  Widget tabs(int index, List<int> first, List<int> second) => Directionality(
        textDirection: TextDirection.ltr,
        child: FadeIndexedStack(
          index: index,
          duration: const Duration(milliseconds: 100),
          children: [_Spinner(first), _Spinner(second)],
        ),
      );

  testWidgets("a hidden tab's animations stop, and run again when it's shown", (tester) async {
    final home = [0], search = [0];
    await tester.pumpWidget(tabs(0, home, search));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(home[0], greaterThan(0));
    expect(search[0], 0, reason: 'the search tab is hidden');

    // Switch to search; once the fade is over, home stops.
    await tester.pumpWidget(tabs(1, home, search));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 50));
    final homeAfterFade = home[0];
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(home[0], homeAfterFade, reason: 'home is hidden now');
    expect(search[0], greaterThan(0));

    // Back to home: it picks up again.
    await tester.pumpWidget(tabs(0, home, search));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
    expect(home[0], greaterThan(homeAfterFade));
  });
}
