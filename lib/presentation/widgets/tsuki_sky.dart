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

/// The nebula, baked (perf): the shader is several octaves of warped noise
/// per pixel, which at full resolution and 60 fps was the heaviest thing the
/// entrance drew (on a mid-range phone the login and onboarding lagged).
/// It's smoke, soft and slow, so it's rendered at half the logical size and
/// refreshed [bakesPerSecond] times a second; each frame draws that image
/// scaled up, which costs next to nothing.
class NebulaPainter extends CustomPainter {
  NebulaPainter(this.shader, {required this.time, required this.intensity, required this.still})
    : super(repaint: still ? intensity : Listenable.merge([time, intensity]));

  final ui.FragmentShader shader;
  final ValueListenable<double> time;
  final Animation<double> intensity;
  final bool still;

  /// How often the drifting nebula is re-rendered.
  static const double bakesPerSecond = 15;

  /// The baked image's size against the logical size.
  static const double resolution = 0.5;

  // One nebula is on screen at a time (loading, login, onboarding share it).
  static ui.Image? _image;
  static Size _size = Size.zero;
  static double _bakedTime = double.negativeInfinity;
  static double _bakedIntensity = -1;

  /// How many times the shader has run (for tests).
  @visibleForTesting
  static int bakes = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = still ? 0.0 : time.value;
    final k = intensity.value;
    final stale = _image == null ||
        size != _size ||
        (k - _bakedIntensity).abs() > 0.01 ||
        (t - _bakedTime).abs() >= 1 / bakesPerSecond;
    if (stale) _bake(size, t, k);
    final image = _image!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _bake(Size size, double t, double k) {
    final w = math.max(1, (size.width * resolution).round());
    final h = math.max(1, (size.height * resolution).round());
    shader
      ..setFloat(0, w.toDouble())
      ..setFloat(1, h.toDouble())
      ..setFloat(2, t)
      ..setFloat(3, k);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    _image?.dispose();
    _image = image;
    bakes++;
    _size = size;
    _bakedTime = t;
    _bakedIntensity = k;
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

/// The login's halo around the mask: a lunar dial.
///
/// From the inside out: a dotted ring turning the other way, the track
/// with a comet running on it (a long tail, a white-hot head), sixty ticks
/// (a longer one every five) and the eight phases of the moon, from new to
/// full. Ticks, dots and phases light up as the comet passes them, so the
/// dial reads as one thing in motion.
///
/// [assemble] (0 to 1) builds it: the track draws itself from the top, the
/// ticks grow out in turn, the dotted ring turns into place and the phases
/// pop in one by one. [exit] fades it out, opening a little.
///
/// Light on purpose (it repaints every frame on the login): a few hundred
/// short lines and circles, gradients instead of blurs, the phases' shapes
/// made once.
class HaloRingPainter extends CustomPainter {
  HaloRingPainter({
    required this.rotation,
    required this.assemble,
    required this.exit,
    required this.still,
    this.burst = const AlwaysStoppedAnimation<double>(0),
    this.radius = 112,
  }) : super(repaint: Listenable.merge([rotation, assemble, exit, burst]));

  /// The comet's turn, in radians (its owner sets the pace: calm, or fast
  /// while signing in).
  final ValueListenable<double> rotation;
  final Animation<double> assemble;
  final Animation<double> exit;
  final bool still;
  final double radius;

  /// Letting you in (0 to 1, linear): a burst of waves runs out of the
  /// ring, the track flashes, the ticks fly out and the phases scatter.
  final Animation<double> burst;

  static const int tickCount = 60;

  /// The waves of the burst: when each leaves (0 to 1 of it) and how far
  /// it runs, as a multiple of the ring.
  static const List<(double, double)> _waves = [(0, 2.1), (0.1, 2.5), (0.2, 2.9), (0.32, 3.4)];
  static const int dotCount = 90;
  static const int phaseCount = 8;

  /// How far behind its head the comet's tail runs, in radians.
  static const double tail = 2.6;

  // Each phase's lit shape on a unit disc: new moon (none) to full, waxing.
  static final List<Path?> _phases = List.generate(phaseCount, (k) {
    if (k == 0) return null;
    final disc = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));
    if (k == phaseCount ~/ 2) return disc;
    // Lit fraction 0..1..0 over the cycle; the shadow is the disc shifted.
    final f = k <= phaseCount ~/ 2 ? k / (phaseCount / 2) : 2 - k / (phaseCount / 2);
    final waxing = k < phaseCount ~/ 2;
    final shift = 2 * f * (waxing ? -1 : 1);
    final shadow = Path()..addOval(Rect.fromCircle(center: Offset(shift, 0), radius: 1));
    return Path.combine(PathOperation.difference, disc, shadow);
  });

  static double _ease(double t) => Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

  /// How close [a] is to the comet's head [head] (1 on it, 0 a bit away),
  /// stronger along the tail behind it than ahead.
  static double _near(double a, double head) {
    var d = (head - a) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi; // -π..π, positive = behind the head
    if (d >= 0) return math.max(0, 1 - d / 0.9);
    return math.max(0, 1 + d / 0.25);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final b = burst.value;
    if (b > 0 && b < 1 && !still) _paintBurst(canvas, c, b);
    final fade = 1 - exit.value;
    final a = assemble.value;
    if (fade <= 0 || a <= 0) return;
    // The burst throws what's around the ring outwards.
    final fling = 46 * Curves.easeOutCubic.transform(b);
    final r = radius * (1 + 0.35 * exit.value);
    final turn = still ? 0.0 : rotation.value;
    final head = -math.pi / 2 + turn;
    final accent = AppColors.accent;

    // The track, drawing itself clockwise from the top.
    final drawn = 2 * math.pi * _ease(a / 0.7);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      drawn,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 2.5 * _flash(b)
        ..color = Color.lerp(accent, Colors.white, 0.5 * _flash(b))!
            .withValues(alpha: ((0.28 + 0.72 * _flash(b)) * fade).clamp(0.0, 1.0)),
    );

    // A faint sweep trailing the comet across the inside, like a radar's.
    final sweepIn = _ease((a - 0.45) / 0.4);
    if (sweepIn > 0 && !still) {
      const wedge = 1.1;
      final inner = r - 16;
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(head - wedge)
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..arcTo(Rect.fromCircle(center: Offset.zero, radius: inner), 0, wedge, false)
            ..close(),
          Paint()
            ..shader = ui.Gradient.sweep(
              Offset.zero,
              [accent.withValues(alpha: 0), accent.withValues(alpha: 0.10 * sweepIn * fade)],
              const [0, 1],
              TileMode.clamp,
              0,
              wedge,
            ),
        )
        ..restore();
    }

    // Two brackets of a HUD outside the ticks, turning slowly the other way.
    final brackets = _ease((a - 0.3) / 0.5);
    if (brackets > 0) {
      final spin = -turn * 0.18 + (1 - brackets) * math.pi / 3;
      final rb = r + 21;
      final bracket = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.42 * brackets * fade);
      for (final base in const [math.pi / 4, math.pi * 5 / 4]) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: rb), base + spin, 0.62 * brackets, false, bracket);
      }
    }

    // The dotted ring inside, turning the other way, into place.
    final dotsIn = _ease((a - 0.15) / 0.6);
    if (dotsIn > 0) {
      final spin = -turn * 0.35 - (1 - dotsIn) * math.pi / 2;
      final rd = r - 12;
      final dot = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < dotCount; i++) {
        final ang = spin + i * 2 * math.pi / dotCount;
        final lit = _near(ang, head);
        dot
          ..strokeWidth = 1.4 + 0.8 * lit
          ..color = Color.lerp(AppColors.textMuted, accent, 0.4 + 0.6 * lit)!
              .withValues(alpha: (0.16 + 0.6 * lit) * dotsIn * fade);
        final p = c + Offset(math.cos(ang), math.sin(ang)) * rd;
        canvas.drawLine(p, p, dot);
      }
    }

    // Sixty ticks outside, growing out in turn from the top.
    final tick = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < tickCount; i++) {
      final grow = _ease((a - 0.1 - 0.4 * i / tickCount) / 0.3);
      if (grow <= 0) continue;
      final ang = -math.pi / 2 + i * 2 * math.pi / tickCount;
      final major = i % 5 == 0;
      final lit = _near(ang, head);
      final dir = Offset(math.cos(ang), math.sin(ang));
      final len = (major ? 9.0 : 4.5) * grow * (1 + 0.4 * lit);
      tick.color = (lit > 0.5 ? Color.lerp(accent, Colors.white, (lit - 0.5) * 0.8)! : accent)
          .withValues(alpha: ((major ? 0.5 : 0.28) + 0.5 * lit).clamp(0.0, 1.0) * fade);
      final out = r + 7 + fling * (major ? 1.2 : 0.8);
      canvas.drawLine(c + dir * out, c + dir * (out + len * (1 + b)), tick);
    }

    // The comet: a long tail fading in behind a white-hot head.
    final comet = _ease((a - 0.35) / 0.4);
    if (comet > 0) {
      final rect = Rect.fromCircle(center: Offset.zero, radius: r);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(head - tail)
        ..drawArc(
          rect,
          0,
          tail,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.sweep(
              Offset.zero,
              [
                accent.withValues(alpha: 0),
                accent.withValues(alpha: 0.55 * comet * fade),
                Color.lerp(accent, Colors.white, 0.5)!.withValues(alpha: comet * fade),
              ],
              const [0, 0.7, 1],
              TileMode.clamp,
              0,
              tail,
            ),
        )
        ..restore();
      // Its head: a soft glow (a gradient, not a blur) and a bright core.
      final h = c + Offset(math.cos(head), math.sin(head)) * r;
      canvas
        ..drawCircle(
          h,
          14,
          Paint()
            ..shader = ui.Gradient.radial(h, 14, [
              accent.withValues(alpha: 0.55 * comet * fade),
              accent.withValues(alpha: 0),
            ]),
        )
        ..drawCircle(h, 2.4, Paint()..color = Colors.white.withValues(alpha: comet * fade));
    }

    // The eight phases of the moon on their own faint orbit, popping in one
    // by one.
    final rp = r + 30;
    final orbit = _ease((a - 0.4) / 0.4);
    if (orbit > 0) {
      canvas.drawCircle(
        c,
        rp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = AppColors.textMuted.withValues(alpha: 0.10 * orbit * fade),
      );
    }
    for (var k = 0; k < phaseCount; k++) {
      final pop = Curves.easeOutBack.transform(((a - 0.45 - k * 0.05) / 0.25).clamp(0.0, 1.0));
      if (pop <= 0) continue;
      final ang = -math.pi / 2 + k * 2 * math.pi / phaseCount;
      final lit = _near(ang, head);
      final p = c + Offset(math.cos(ang), math.sin(ang)) * (rp + fling * 1.6);
      final s = 4.4 * pop * (1 + 0.25 * lit);
      // The whole disc, faint (the unlit side), then its lit part.
      canvas.drawCircle(
        p,
        s,
        Paint()..color = AppColors.textMuted.withValues(alpha: (0.14 + 0.1 * lit) * fade),
      );
      final shape = _phases[k];
      if (shape != null) {
        canvas
          ..save()
          ..translate(p.dx, p.dy)
          ..scale(s)
          ..drawPath(
            shape,
            Paint()
              ..color = Color.lerp(AppColors.textMuted, Colors.white, 0.35 + 0.65 * lit)!
                  .withValues(alpha: (0.45 + 0.55 * lit) * fade),
          )
          ..restore();
      }
    }
  }

  /// The track's flash: up at once as the burst starts, then down.
  static double _flash(double b) => b <= 0 ? 0 : (b < 0.08 ? b / 0.08 : math.max(0, 1 - (b - 0.08) / 0.5));

  void _paintBurst(Canvas canvas, Offset c, double b) {
    for (var i = 0; i < _waves.length; i++) {
      final (start, reach) = _waves[i];
      final t = (b - start) / 0.6;
      if (t <= 0 || t >= 1) continue;
      final e = Curves.easeOutCubic.transform(t);
      final wr = radius * (1 + (reach - 1) * e);
      final alpha = math.pow(1 - t, 1.4).toDouble();
      final last = i == _waves.length - 1;
      final color = last ? Color.lerp(AppColors.accent, Colors.white, 0.6)! : AppColors.accent;
      // A soft band and a sharp edge, thinning as it runs out.
      canvas
        ..drawCircle(
          c,
          wr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 18 * (1 - t) + 2
            ..color = AppColors.accent.withValues(alpha: 0.12 * alpha),
        )
        ..drawCircle(
          c,
          wr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2 * (1 - t) + 0.6
            ..color = color.withValues(alpha: 0.85 * alpha),
        );
    }
    // A flash at the heart, under the mask.
    final glow = math.max(0.0, 1 - b / 0.35);
    if (glow > 0) {
      final gr = radius * (0.8 + 0.6 * b);
      canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = ui.Gradient.radial(c, gr, [
            AppColors.accent.withValues(alpha: 0.35 * glow),
            AppColors.accent.withValues(alpha: 0),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(HaloRingPainter old) => old.still != still || old.radius != radius;
}
