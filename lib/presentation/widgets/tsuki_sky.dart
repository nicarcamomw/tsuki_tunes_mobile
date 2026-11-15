import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The night of Tsuki's entrance, shared by the loading screen and the
/// login so they read as one scene: the crimson nebula (a GPU shader), the
/// embers, the glow and the moon ring around the mask. All of them repaint
/// from listenables (a continuous time, an animation) without rebuilding.

/// The splash's glow, the one Android's animated splash ends with.
const double splashGlowRadius = 93;
const double splashGlowAlpha = 0.20;

/// The nebula's program, loaded once (null where shaders can't load: the
/// night stays plain).
final Future<ui.FragmentProgram?> tsukiNebulaProgram = ui.FragmentProgram.fromAsset(
  'shaders/tsuki_nebula.frag',
).then<ui.FragmentProgram?>((p) => p).catchError((Object _) => null);

/// A slow breath (0..1) every 2.8 s, from the continuous time.
double breathAt(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t / 2.8);

class NebulaPainter extends CustomPainter {
  NebulaPainter(this.shader, {required this.time, required this.intensity, required this.still})
    : super(repaint: still ? intensity : Listenable.merge([time, intensity]));

  final ui.FragmentShader shader;
  final ValueListenable<double> time;
  final Animation<double> intensity;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, still ? 0 : time.value)
      ..setFloat(3, intensity.value);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(NebulaPainter old) => old.shader != shader || old.still != still;
}

/// Sixteen embers rising slowly and twinkling out, each on its own path.
class EmbersPainter extends CustomPainter {
  EmbersPainter({required this.time, required this.intensity, required this.exit})
    : super(repaint: Listenable.merge([time, intensity, exit]));

  final ValueListenable<double> time;
  final Animation<double> intensity;
  final Animation<double> exit;

  static final List<(double, double, double, double)> _embers = () {
    final rng = math.Random(7);
    return List.generate(
      16,
      (_) => (
        0.18 + rng.nextDouble() * 0.64,
        0.05 + rng.nextDouble() * 0.06,
        rng.nextDouble(),
        0.8 + rng.nextDouble() * 1.4,
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final k = intensity.value * (1 - exit.value);
    if (k <= 0) return;
    final paint = Paint();
    for (final (x, speed, phase, radius) in _embers) {
      final life = (time.value * speed + phase) % 1;
      final alpha = math.sin(math.pi * life) * 0.55 * k;
      final drift = math.sin((time.value + phase * 10) * 0.7) * 10;
      final pos = Offset(x * size.width + drift, size.height * (0.82 - 0.62 * life));
      paint.color = AppColors.accent.withValues(alpha: alpha);
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(EmbersPainter old) => false;
}

class MoonGlowPainter extends CustomPainter {
  MoonGlowPainter({required this.grow, required this.time, required this.exit, required this.still})
    : super(repaint: Listenable.merge([grow, time, exit]));

  final Animation<double> grow;
  final ValueListenable<double> time;
  final Animation<double> exit;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final breath = still ? 0.0 : breathAt(time.value);
    // From the splash's glow to the breathing one, then a flash on leaving.
    final radius = ui.lerpDouble(splashGlowRadius, 130, grow.value)! * (1 + 0.6 * exit.value);
    final alpha =
        ui.lerpDouble(splashGlowAlpha, 0.14 + 0.08 * breath, grow.value)! * (1 + exit.value) * (1 - exit.value);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius, [
          AppColors.accent.withValues(alpha: alpha.clamp(0, 1)),
          AppColors.accent.withValues(alpha: 0),
        ]),
    );
    // The mask's soft shadow, lifting it off the glow (comes in with it).
    final shadow = 0.45 * grow.value * (1 - exit.value);
    if (shadow > 0) {
      canvas
        ..save()
        ..translate(centre.dx, centre.dy + 74)
        ..scale(1, 0.22)
        ..drawCircle(
          Offset.zero,
          62,
          Paint()
            ..shader = ui.Gradient.radial(Offset.zero, 62, [
              Colors.black.withValues(alpha: shadow),
              Colors.black.withValues(alpha: 0),
            ]),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(MoonGlowPainter old) => old.still != still;
}

class MoonRingPainter extends CustomPainter {
  MoonRingPainter({
    required this.sweep,
    required this.pulse,
    required this.ticks,
    required this.rotation,
    required this.exit,
    required this.still,
    this.radius = 112,
  }) : super(repaint: Listenable.merge([sweep, pulse, ticks, rotation, exit]));

  final Animation<double> sweep;
  final Animation<double> pulse;
  final Animation<double> ticks;

  /// The ring's turn, in radians (its owner decides the pace: slow while
  /// waiting, fast as a loader).
  final ValueListenable<double> rotation;
  final Animation<double> exit;
  final bool still;

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final fade = 1 - exit.value;
    final s = sweep.value;
    if (fade <= 0 || s <= 0) return;
    final r = radius * (1 + 0.5 * exit.value);
    final turn = still ? 0.0 : rotation.value;
    final start = -math.pi / 2 + turn;

    // The faint track, coming in with the ring (the splash has none).
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.textMuted.withValues(alpha: 0.10 * fade * math.min(1, s * 3)),
    );
    // The drawn arc.
    final angle = 2 * math.pi * s;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      start,
      angle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.5 * fade),
    );
    // The comet at its head, in its own turn of the canvas so its gradient
    // runs over 0..comet (a sweep gradient wants angles in 0..2π).
    const comet = 1.2; // radians
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(start + angle - comet)
      ..drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        0,
        comet,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.sweep(
            Offset.zero,
            [AppColors.accent.withValues(alpha: 0), AppColors.accent.withValues(alpha: fade)],
            const [0, 1],
            TileMode.clamp,
            0,
            comet,
          ),
      )
      ..restore();

    // Closed: a ripple runs out from the ring, once.
    final p = pulse.value;
    if (p > 0 && p < 1) {
      canvas.drawCircle(
        centre,
        r * (1 + 0.35 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 + 2 * (1 - p)
          ..color = AppColors.accent.withValues(alpha: 0.6 * (1 - p) * fade),
      );
    }

    // HUD ticks around it, every 30°.
    final t = ticks.value * fade;
    if (t > 0) {
      final tick = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.5 * t);
      for (var i = 0; i < 12; i++) {
        final a = start + i * math.pi / 6;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(centre + dir * (r + 6), centre + dir * (r + (i % 3 == 0 ? 14 : 10)), tick);
      }
    }
  }

  @override
  bool shouldRepaint(MoonRingPainter old) => old.still != still;
}
