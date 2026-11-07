import 'package:flutter/widgets.dart';

/// Gives [child] a short pop whenever [value] changes: a song marked as
/// listened, an artist followed. Not on the first build, so a list scrolled
/// into view doesn't pop, and never with reduced motion.
class PopOnChange extends StatefulWidget {
  final Object? value;
  final Widget child;

  /// How big the pop gets at its peak.
  final double peak;

  const PopOnChange({super.key, required this.value, required this.child, this.peak = 1.22});

  static const duration = Duration(milliseconds: 420);

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: PopOnChange.duration);

  late Animation<double> _scale = _build();

  Animation<double> _build() => TweenSequence<double>([
        // Up quickly, then settle with a little spring.
        TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.peak).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
        TweenSequenceItem(tween: Tween(begin: widget.peak, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
      ]).animate(_controller);

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.peak != widget.peak) _scale = _build();
    if (old.value != widget.value && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}
