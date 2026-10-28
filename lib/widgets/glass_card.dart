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
    final border = Border.all(
      color: widget.color.withValues(alpha: widget.borderAlpha),
    );

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
          border: border,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value * 2 * pi;
        final dx = sin(t + _phase) * 0.5;
        final dy = cos(t * 0.7 + _phase) * 0.35;

        return Container(
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + dx, -1.0 + dy),
              end: Alignment(1.0 - dx * 0.4, 1.0 - dy * 0.4),
              colors: [
                widget.color.withValues(alpha: widget.highlightAlpha),
                AppColors.bgCard,
                widget.color.withValues(alpha: widget.dimAlpha),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: border,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
