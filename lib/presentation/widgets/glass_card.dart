import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Color color;
  final double highlightAlpha;
  final double dimAlpha;
  final double borderAlpha;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Widget child;

  const GlassCard({
    super.key,
    required this.color,
    this.highlightAlpha = 0.15,
    this.dimAlpha = 0.05,
    this.borderAlpha = 0.4,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    required this.child,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    _phase = Random().nextDouble() * 2 * pi;
    // Slow on purpose: the glass should drift, not flash. Every motion in
    // the painter is periodic over one cycle, so the loop never jumps.
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final br = BorderRadius.circular(widget.borderRadius);
    final borderColor = widget.color.withValues(alpha: widget.borderAlpha);

    if (reduceMotion) {
      return Container(
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: br,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withValues(alpha: widget.highlightAlpha),
              AppColors.bgCard,
            ],
          ),
          border: Border.all(color: borderColor),
        ),
        child: widget.child,
      );
    }

    Widget inner = RepaintBoundary(
      child: CustomPaint(
        painter: _GlassPainter(
          color: widget.color,
          highlightAlpha: widget.highlightAlpha,
          dimAlpha: widget.dimAlpha,
          borderAlpha: widget.borderAlpha,
          borderRadius: widget.borderRadius,
          bgCard: AppColors.bgCard,
          phase: _phase,
          animation: _anim,
        ),
        child: Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );

    if (widget.margin != null) {
      inner = Padding(padding: widget.margin!, child: inner);
    }

    return inner;
  }
}

class _GlassPainter extends CustomPainter {
  final Color color;
  final double highlightAlpha;
  final double dimAlpha;
  final double borderAlpha;
  final double borderRadius;
  final Color bgCard;
  final double phase;

  _GlassPainter({
    required this.color,
    required this.highlightAlpha,
    required this.dimAlpha,
    required this.borderAlpha,
    required this.borderRadius,
    required this.bgCard,
    required this.phase,
    required Animation<double> animation,
  }) : _animation = animation, super(repaint: animation);

  final Animation<double> _animation;

  // Frosted-glass grain, fixed per card size so it never shimmers.
  List<Offset>? _grain;
  Size? _grainSize;

  List<Offset> _grainFor(Size size) {
    if (_grain != null && _grainSize == size) return _grain!;
    final rng = Random((phase * 1000).round());
    final count = (size.width * size.height / 90).round().clamp(40, 900);
    _grainSize = size;
    return _grain = [
      for (var i = 0; i < count; i++)
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    // One full turn per cycle; only whole multiples of t below, so the
    // last frame matches the first.
    final t = _animation.value * 2 * pi;
    final longest = max(size.width, size.height);

    canvas.save();
    canvas.clipRRect(rrect);

    // Base: the card tinted from the top-left corner, static.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(color.withValues(alpha: highlightAlpha * 0.8), bgCard),
            bgCard,
            Color.alphaBlend(color.withValues(alpha: dimAlpha), bgCard),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    // Caustics: soft pools of light drifting on looping paths, like light
    // bent through thick glass.
    const blobs = [
      (fx: 1, fy: 1, ox: 0.0, r: 0.75, a: 1.0),
      (fx: 1, fy: 2, ox: 2.1, r: 0.55, a: 0.7),
      (fx: 2, fy: 1, ox: 4.2, r: 0.45, a: 0.5),
    ];
    for (final b in blobs) {
      final cx = size.width * (0.5 + 0.42 * sin(b.fx * t + phase + b.ox));
      final cy = size.height * (0.5 + 0.38 * cos(b.fy * t + phase * 1.3 + b.ox));
      final radius = longest * b.r;
      final center = Offset(cx, cy);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: highlightAlpha * 0.55 * b.a),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Ripples: faint wavy refraction lines that slowly undulate.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 0; i < 4; i++) {
      final path = Path();
      final baseY = size.height * (0.18 + i * 0.22);
      final amp = size.height * (0.05 + 0.025 * sin(t + i));
      for (double x = 0; x <= size.width; x += 6) {
        final y = baseY +
            amp * sin(x / size.width * 2 * pi * (1.2 + i * 0.35) + t * (i.isEven ? 1 : -1) + phase + i);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, ripple);
    }

    // Frosted grain.
    canvas.drawPoints(
      PointMode.points,
      _grainFor(size),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.045)
        ..strokeWidth = 1,
    );

    // Sheen: a wide diagonal glint that crosses once per cycle and fades
    // in and out, so it's invisible where the loop wraps.
    final v = _animation.value;
    final glint = pow(sin(pi * v), 2).toDouble();
    if (glint > 0.01) {
      final sweep = -0.6 + 2.2 * v;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1 + sweep * 2 - 0.6, -1),
            end: Alignment(-1 + sweep * 2 + 0.6, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.05 * glint),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    canvas.restore();

    // Glass rim: border in the card's color, brighter along the top edge.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.25)!.withValues(alpha: borderAlpha),
            color.withValues(alpha: borderAlpha * 0.6),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.color != color ||
      old.highlightAlpha != highlightAlpha ||
      old.dimAlpha != dimAlpha ||
      old.borderAlpha != borderAlpha ||
      old.borderRadius != borderRadius ||
      old.bgCard != bgCard ||
      old.phase != phase;
}
