import 'package:flutter/widgets.dart';
import '../../core/theme/design_tokens.dart';

/// Gives [child] a short pop whenever [value] changes: a song marked as
/// listened, an artist followed. Not on the first build, so a list scrolled
/// into view doesn't pop, and never with reduced motion.
class PopOnChange extends StatefulWidget {
  final Object? value;
  final Widget child;

  /// How big the pop gets at its peak.
  final double peak;

  const PopOnChange({super.key, required this.value, required this.child, this.peak = 1.22});

  static const duration = AppMotion.slow;

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  // Made on the first change only: a list shows this in every row, and most
  // rows never pop.
  AnimationController? _controller;
  Animation<double>? _scale;

  static const _still = AlwaysStoppedAnimation<double>(1.0);

  Animation<double> _build(AnimationController controller) => TweenSequence<double>([
        // Up quickly, then settle with a little spring.
        TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.peak).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
        TweenSequenceItem(tween: Tween(begin: widget.peak, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
      ]).animate(controller);

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      if (old.peak != widget.peak && _controller != null) _scale = _build(_controller!);
      return;
    }
    final controller = _controller ??= AnimationController(vsync: this, duration: PopOnChange.duration);
    if (_scale == null || old.peak != widget.peak) _scale = _build(controller);
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Always a ScaleTransition, so the child is never rebuilt from scratch
  // when the first pop arrives.
  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale ?? _still, child: widget.child);
}
