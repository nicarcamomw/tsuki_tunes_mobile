import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.fast,
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _targetIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.index;
    _previousIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.duration = Duration.zero;
    }
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _targetIndex) {
      if (_controller.isAnimating) {
        if (widget.index == _previousIndex) {
          final currentProgress = _controller.value;
          _previousIndex = _targetIndex;
          _targetIndex = widget.index;
          _controller.forward(from: (1.0 - currentProgress).clamp(0.0, 1.0));
          return;
        }

        if (_controller.value < 0.5) {
          _targetIndex = widget.index;
          _controller.forward(from: 0.0);
          return;
        }
      }

      _previousIndex = _targetIndex;
      _targetIndex = widget.index;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeInOut.transform(_controller.value);
        final isAnimating = _controller.isAnimating;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final isTarget = i == _targetIndex;
            final isPrevious = i == _previousIndex && isAnimating;
            final isOffstage = !isTarget && !isPrevious;

            double opacity;
            if (isAnimating) {
              if (isTarget) {
                opacity = progress;
              } else if (isPrevious) {
                opacity = 1.0 - progress;
              } else {
                opacity = 0.0;
              }
            } else {
              opacity = isTarget ? 1.0 : 0.0;
            }

            return Offstage(
              offstage: isOffstage,
              // Offstage alone doesn't stop animations: a hidden tab's
              // orb, visualizers and glitches would keep ticking (and
              // asking for frames). Muted here, like the Navigator does
              // for covered screens; they pick up again when shown.
              child: TickerMode(
                enabled: !isOffstage,
                child: ExcludeFocus(
                  excluding: !isTarget,
                  child: IgnorePointer(
                    ignoring: !isTarget,
                    child: FadeTransition(
                      opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
