import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import 'motion.dart';

/// A one-line title that slides to show what doesn't fit, then comes back.
///
/// Built to cost nothing while it waits (perf): the slide is a paint-only
/// translation of an already laid-out line (no scroll view relaid out every
/// frame), and the pauses at each end are timers, so no frame is asked for
/// while the text stands still. A title that fits, or reduce motion, never
/// animates. The old marquees ran a ticker through their pauses, forever:
/// with a long title the whole app redrew 60 times a second.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  /// How long it rests at each end.
  static const Duration pause = Duration(milliseconds: 1800);

  /// Pixels per second while sliding.
  static const double speed = 25;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this);
  Timer? _wait;
  double _overflow = 0;
  bool _running = false;

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.style != widget.style) _stop();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _slide.dispose();
    super.dispose();
  }

  void _stop() {
    _wait?.cancel();
    _slide
      ..stop()
      ..value = 0;
    _running = false;
  }

  void _run(double overflow) {
    _overflow = overflow;
    if (_running) return;
    _running = true;
    _cycle();
  }

  void _cycle() {
    _wait = Timer(MarqueeText.pause, () async {
      if (!mounted || !_running) return;
      final there = Duration(milliseconds: (_overflow / MarqueeText.speed * 1000).round().clamp(1200, 8000));
      await _slide.animateTo(1, duration: there, curve: Curves.linear).orCancel.catchError((_) {});
      if (!mounted || !_running) return;
      _wait = Timer(MarqueeText.pause, () async {
        if (!mounted || !_running) return;
        await _slide.animateBack(0, duration: AppMotion.slow, curve: AppMotion.move).orCancel.catchError((_) {});
        if (mounted && _running) _cycle();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final line = Text(widget.text, style: widget.style, maxLines: 1, softWrap: false);
    // Its own semantics node (as the scroll view it replaced was): a row
    // that labels itself ("title, artist") doesn't read the title twice.
    return Semantics(
      container: true,
      child: LayoutBuilder(builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final overflow = painter.width - box.maxWidth;
      final height = painter.height;
      painter.dispose();
      if (overflow <= 0.5 || reduceMotion(context)) {
        if (_running) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _stop() : null);
        return Text(widget.text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(overflow);
      });
      return ClipRect(
        child: SizedBox(
          height: height,
          width: box.maxWidth,
          child: AnimatedBuilder(
            animation: _slide,
            // Laid out and painted once; only its offset changes.
            child: RepaintBoundary(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: 0,
                maxWidth: double.infinity,
                child: line,
              ),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(-overflow * _slide.value, 0),
              child: child,
            ),
          ),
        ),
      );
    }),
    );
  }
}
