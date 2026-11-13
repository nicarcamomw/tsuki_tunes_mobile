import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'motion.dart';

/// P-08: the app's "loading", the moon going through its phases (new,
/// crescent, full, waning) instead of Material's spinner. Drawn with two
/// ovals, so it costs nothing to animate; still (a half moon) with reduce
/// motion.
class MoonLoader extends StatefulWidget {
  const MoonLoader({super.key, this.size = 24, this.color = AppColors.moonlight, this.semanticLabel});

  final double size;
  final Color color;

  /// What TalkBack says; without it, it's decoration (the screen says it's
  /// loading).
  final String? semanticLabel;

  @override
  State<MoonLoader> createState() => _MoonLoaderState();
}

class _MoonLoaderState extends State<MoonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _cycle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _cycle
        ..stop()
        ..value = 0.25;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moon = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _PhasePainter(_cycle, widget.color),
      ),
    );
    return widget.semanticLabel == null
        ? ExcludeSemantics(child: moon)
        : Semantics(label: widget.semanticLabel, liveRegion: true, child: moon);
  }
}

class _PhasePainter extends CustomPainter {
  _PhasePainter(this.phase, this.color) : super(repaint: phase);

  /// 0 new → 0.5 full → 1 new again.
  final Animation<double> phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final disc = Rect.fromCircle(center: c, radius: r);
    // The dark side, faintly, so the moon keeps its shape at new moon.
    canvas.drawOval(disc, Paint()..color = color.withValues(alpha: 0.14));

    final p = phase.value;
    final waxing = p < 0.5;
    // How far the terminator is from the centre: -1 (new) .. 1 (full).
    final k = math.cos(p * 2 * math.pi) * -1;
    final lit = Path();
    // The lit half (right while waxing, left while waning)...
    lit.addArc(disc, waxing ? -math.pi / 2 : math.pi / 2, math.pi);
    // ...closed by the terminator, an ellipse of half-width |k|·r.
    final term = Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r);
    final shape = Path()..addOval(term);
    final Path moon = k >= 0
        ? Path.combine(PathOperation.union, lit, shape)
        : Path.combine(PathOperation.difference, lit, shape);
    canvas.drawPath(moon, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PhasePainter old) => old.color != color;
}
