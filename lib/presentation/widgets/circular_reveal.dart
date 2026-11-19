import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Where the next [CircularReveal] opens from, as a place on the screen.
///
/// The screen that leaves sets it (the login puts it on its mask, so the
/// app opens out of the mask); without one it's the centre, where the
/// entrance's mask is.
abstract final class RevealOrigin {
  static Alignment value = Alignment.center;
}

/// [child] coming in through a circle that opens from [origin] to the whole
/// screen, its edge a ring of crimson light running out like a wave: the
/// eclipse the entrance, the login and the app open with.
///
/// Light: one clip and two strokes per frame while it opens; once open the
/// clip is off and nothing is drawn, with the same widgets (the page below
/// isn't rebuilt).
class CircularReveal extends StatelessWidget {
  const CircularReveal({super.key, required this.animation, required this.child, this.origin});

  final Animation<double> animation;
  final Widget child;

  /// Where it opens from; [RevealOrigin.value] when null.
  final Alignment? origin;

  /// The opening's pace: slow out of the mask, fast across, gentle at the end.
  static const Curve curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final from = origin ?? RevealOrigin.value;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Leaving (the route popped or replaced: signing out), it simply
        // fades: closing the circle back into a mask that isn't there
        // crossed the next screen's own opening.
        if (animation.status == AnimationStatus.reverse) {
          return Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child);
        }
        final t = curve.transform(animation.value);
        final open = animation.value >= 1;
        return CustomPaint(
          foregroundPainter: _RimPainter(t: open ? 1 : t, origin: from),
          child: ClipPath(
            clipper: _CircleClipper(t, from),
            clipBehavior: open ? Clip.none : Clip.antiAlias,
            // Coming through the circle: a touch larger, settling as it
            // opens (depth, as if passing through it).
            child: Transform.scale(
              scale: open ? 1 : 1 + 0.06 * (1 - t),
              alignment: from,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

double _radiusFor(Size size, Alignment origin, double t) {
  final c = origin.alongSize(size);
  final far = [
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ].map((p) => (p - c).distance).reduce(math.max);
  // A little past the far corner, so the rim leaves the screen.
  return (far + 30) * t;
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.t, this.origin);

  final double t;
  final Alignment origin;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: origin.alongSize(size), radius: _radiusFor(size, origin, t)));

  @override
  bool shouldReclip(_CircleClipper old) => old.t != t || old.origin != origin;
}

/// The light on the opening's edge: a wide soft band and a bright core,
/// fading as it reaches the corners.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.t, required this.origin});

  final double t;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = origin.alongSize(size);
    final r = _radiusFor(size, origin, t);
    // Not over the mask it opens from (small circles there): it lights up
    // once past it, and fades as it reaches the corners.
    final fade = (1 - t) * Curves.easeIn.transform(((t - 0.08) / 0.14).clamp(0.0, 1.0));
    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..color = AppColors.accent.withValues(alpha: 0.16 * fade),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = AppColors.accent.withValues(alpha: 0.9 * fade),
      )
      ..drawCircle(
        c,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.6 * fade),
      );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.t != t || old.origin != origin;
}
