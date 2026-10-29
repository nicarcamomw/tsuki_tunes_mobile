import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

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
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final t = _animation.value * 2 * pi;
    final dx = sin(t + phase) * 0.5;
    final dy = cos(t * 0.7 + phase) * 0.35;

    final shader = LinearGradient(
      begin: Alignment(-1.0 + dx, -1.0 + dy),
      end: Alignment(1.0 - dx * 0.4, 1.0 - dy * 0.4),
      colors: [
        color.withValues(alpha: highlightAlpha),
        bgCard,
        color.withValues(alpha: dimAlpha),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: borderAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
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
