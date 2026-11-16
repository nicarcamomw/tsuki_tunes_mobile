import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Liquid glass, Apple-style but in Tsuki's night: what's behind shows
/// through blurred, under a veil of [color] ([fill] of it), with light
/// caught on the rim (bright at the top-left, a glint at the bottom-right),
/// a sheen fading down inside, and a soft shadow lifting it off the page.
///
/// With Android's high contrast text on, it's a solid surface: nothing
/// shows through. [opacity] fades the whole effect (a header's title as it
/// collapses); at 0 nothing is drawn and no blur is paid for.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    this.color = AppColors.surfaceRaised,
    this.fill = AppGlass.fill,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.border,
    this.shadow = true,
    this.shadowColor,
    this.sheen = true,
    this.opacity = 1,
    this.blur = true,
    this.child,
  });

  final Color color;

  /// How much of [color] covers what's behind (AppGlass.fill or clearFill).
  final double fill;
  final BorderRadius borderRadius;
  final BoxShape shape;

  /// An outline in place of the rim of light (an error notice's red).
  final BoxBorder? border;

  /// The soft shadow under it.
  final bool shadow;

  /// A glow in place of the black shadow (the mini player's colour).
  final Color? shadowColor;

  /// The sheen inside. Off for a wide bar, where it reads as a grey band.
  final bool sheen;
  final double opacity;

  /// Whether what's behind is blurred. Off over a background that's soft
  /// already (the entrance's nebula): blurring a blur looks the same, and
  /// over something that moves it's worked out again every frame.
  final bool blur;

  final Widget? child;

  /// The veil's key, for tests.
  static const veilKey = ValueKey('glass-veil');

  /// Whether glass shows through here, or stays solid (high contrast).
  static bool showsThrough(BuildContext context) => !(MediaQuery.maybeHighContrastOf(context) ?? false);

  @override
  Widget build(BuildContext context) {
    final clear = showsThrough(context);
    final t = opacity.clamp(0.0, 1.0);
    final circle = shape == BoxShape.circle;
    final radius = circle ? null : borderRadius;

    Widget glass = DecoratedBox(
      key: veilKey,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: color.withValues(alpha: (clear ? fill : 1) * t),
      ),
      child: DecoratedBox(
        // The sheen inside, fading down from the top (a decoration takes a
        // colour or a gradient, not both).
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          gradient: clear && sheen
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.5, 1],
                  colors: [
                    Colors.white.withValues(alpha: AppGlass.sheen * t),
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: AppGlass.sheen * 0.3 * t),
                  ],
                )
              : null,
          border: border,
        ),
        child: CustomPaint(
          foregroundPainter: clear && border == null ? _RimPainter(circle: circle, radius: borderRadius, t: t) : null,
          child: child,
        ),
      ),
    );

    // Always clipped: a backdrop filter blurs everything up to its clip,
    // the whole screen without one.
    Widget clip(Widget w) => circle
        ? ClipOval(child: w)
        : (borderRadius == BorderRadius.zero ? ClipRect(child: w) : ClipRRect(borderRadius: borderRadius, child: w));

    glass = !clear || t == 0 || !blur
        ? clip(glass)
        // Grouped: glasses under one BackdropGroup (the dock) read what's
        // behind them once, for all of them.
        : clip(BackdropFilter.grouped(
            filter: ImageFilter.blur(sigmaX: AppGlass.blur * t, sigmaY: AppGlass.blur * t),
            child: glass,
          ));
    if (!shadow || t == 0) return glass;
    // The shadow only outside the glass: under it, it would show through
    // as a dark stain.
    return CustomPaint(
      painter: _OuterShadowPainter(
        circle: circle,
        radius: borderRadius,
        t: t,
        color: shadowColor ?? Colors.black.withValues(alpha: AppGlass.shadow),
        offset: shadowColor == null ? const Offset(0, 4) : const Offset(0, 2),
      ),
      child: glass,
    );
  }
}

/// A soft shadow under the glass, drawn only around it.
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter({
    required this.circle,
    required this.radius,
    required this.t,
    required this.color,
    required this.offset,
  });

  final bool circle;
  final BorderRadius radius;
  final double t;
  final Color color;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : radius.toRRect(rect);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(40)),
      Path()..addRRect(shape),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        shape.shift(offset),
        Paint()
          ..color = color.withValues(alpha: color.a * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.circle != circle || old.radius != radius || old.t != t || old.color != color || old.offset != offset;
}

/// The light caught on the glass's rim.
class _RimPainter extends CustomPainter {
  _RimPainter({required this.circle, required this.radius, required this.t});

  final bool circle;
  final BorderRadius radius;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : radius.toRRect(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.35, 0.7, 1],
        colors: [
          Colors.white.withValues(alpha: AppGlass.rimLight * t),
          Colors.white.withValues(alpha: 0.06 * t),
          Colors.white.withValues(alpha: 0.04 * t),
          Colors.white.withValues(alpha: AppGlass.rimGlint * t),
        ],
      ).createShader(rect);
    canvas.drawRRect(shape.deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.circle != circle || old.radius != radius || old.t != t;
}
