import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// The tabs, one shown at a time, each keeping its state (scroll, loaded
/// content) while hidden.
///
/// Changing tabs, the new one fades in over [duration]; the old one goes at
/// once. (120 fps: two whole screens half transparent at the same time made
/// each draw apart, every frame of the change; one is enough.)
///
/// Hidden tabs are offstage and muted (TickerMode): their animations don't
/// tick and ask for frames.
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

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: widget.duration, value: 1);
  late final Animation<double> _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _fade.duration = Duration.zero;
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index,
              child: ExcludeFocus(
                excluding: i != widget.index,
                // Always the same wrapper (the tab keeps its state); fully
                // opaque, it adds no layer, so at rest it costs nothing.
                child: FadeTransition(
                  opacity: i == widget.index ? _opacity : kAlwaysCompleteAnimation,
                  alwaysIncludeSemantics: true,
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
