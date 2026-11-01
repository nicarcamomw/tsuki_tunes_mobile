import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A rendered Moon: real terminator shape for the given illumination, lunar
/// maria, earthshine on the dark side and a halo that grows with the light.
class MoonGlyph extends StatelessWidget {
  final double size;
  final double illumination;
  final bool waxing;
  final bool southernHemisphere;
  final bool eclipse;
  final bool halo;

  const MoonGlyph({
    super.key,
    required this.size,
    required this.illumination,
    required this.waxing,
    this.southernHemisphere = false,
    this.eclipse = false,
    this.halo = true,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final key = MoonImageKey(
      size: size,
      dpr: dpr,
      illumination: eclipse ? 1.0 : illumination.clamp(0.0, 1.0),
      waxing: waxing,
      southern: southernHemisphere,
      eclipse: eclipse,
      halo: halo,
    );
    return CustomPaint(
      size: Size.square(size),
      painter: _MoonImagePainter(MoonImageCache.instance.imageFor(key), key),
    );
  }
}

/// What a baked moon depends on. Illumination is rounded to 0.1%, the same
/// step at which the moon visibly changes.
@immutable
class MoonImageKey {
  final double size;
  final double dpr;
  final int milli;
  final bool waxing;
  final bool southern;
  final bool eclipse;
  final bool halo;

  MoonImageKey({
    required this.size,
    required this.dpr,
    required double illumination,
    required this.waxing,
    required this.southern,
    required this.eclipse,
    required this.halo,
  }) : milli = (illumination * 1000).round();

  /// The halo spreads to twice the moon's radius, past the widget's box.
  double get extent => halo ? size * 2 : size + 2;

  @override
  bool operator ==(Object other) =>
      other is MoonImageKey &&
      other.size == size &&
      other.dpr == dpr &&
      other.milli == milli &&
      other.waxing == waxing &&
      other.southern == southern &&
      other.eclipse == eclipse &&
      other.halo == halo;

  @override
  int get hashCode => Object.hash(size, dpr, milli, waxing, southern, eclipse, halo);
}

/// Baked moons. The painter uses layers, blurs, path boolean ops and, for
/// big moons, a couple hundred craters: fine once, far too heavy to redo on
/// every frame of a sheet sliding in or a list scrolling (Impeller keeps no
/// raster cache). Each look is painted once into an image and reused.
class MoonImageCache {
  MoonImageCache._();
  static final MoonImageCache instance = MoonImageCache._();

  static const int maxEntries = 48;

  // Insertion order doubles as recency: a hit is moved to the end.
  final Map<MoonImageKey, ui.Image> _images = {};

  int get length => _images.length;

  ui.Image imageFor(MoonImageKey key) {
    final hit = _images.remove(key);
    if (hit != null) return _images[key] = hit;

    final extent = key.extent;
    final px = (extent * key.dpr).ceil().clamp(1, 4096);
    final scale = px / extent;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate((extent - key.size) / 2, (extent - key.size) / 2);
    MoonPainter(
      illumination: key.milli / 1000,
      waxing: key.waxing,
      southern: key.southern,
      eclipse: key.eclipse,
      halo: key.halo,
    ).paint(canvas, Size.square(key.size));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(px, px);
    picture.dispose();

    // Evicted images are left to the GC: a widget may still be drawing one.
    if (_images.length >= maxEntries) _images.remove(_images.keys.first);
    return _images[key] = image;
  }

  /// Bakes [keys] ahead of time (recording is cheap; the GPU work runs
  /// off the UI thread), so the first opening of a screen full of moons
  /// doesn't pay for all of them on its first frame.
  void warm(Iterable<MoonImageKey> keys) {
    for (final key in keys) {
      if (!_images.containsKey(key)) imageFor(key);
    }
  }

  @visibleForTesting
  void clear() => _images.clear();
}

class _MoonImagePainter extends CustomPainter {
  final ui.Image image;
  final MoonImageKey key;

  _MoonImagePainter(this.image, this.key);

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Rect.fromCenter(
        center: size.center(Offset.zero), width: key.extent, height: key.extent);
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_MoonImagePainter old) => old.key != key;
}

/// Slow pulse for the blood moon. Static when [active] is false or the system
/// asks to reduce motion.
class MoonBreathing extends StatefulWidget {
  final bool active;
  final Widget child;

  const MoonBreathing({super.key, required this.active, required this.child});

  @override
  State<MoonBreathing> createState() => _MoonBreathingState();
}

class _MoonBreathingState extends State<MoonBreathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.active && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (!animate) {
      if (_c.isAnimating) _c.stop();
      return widget.child;
    }
    if (!_c.isAnimating) _c.repeat(reverse: true);
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.07)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class MoonPainter extends CustomPainter {
  final double illumination;
  final bool waxing;
  final bool southern;
  final bool eclipse;
  final bool halo;

  MoonPainter({
    required this.illumination,
    required this.waxing,
    required this.southern,
    required this.eclipse,
    required this.halo,
  });

  // Main maria on the near side as seen from the northern hemisphere, in
  // unit-disk coordinates (x right, y down): center, radii, rotation.
  static const List<(Offset, Size, double)> _maria = [
    (Offset(-0.47, -0.02), Size(0.27, 0.44), 0.15), // Oceanus Procellarum
    (Offset(-0.22, -0.38), Size(0.25, 0.18), -0.2), // Imbrium
    (Offset(0.12, -0.33), Size(0.14, 0.12), 0.0), // Serenitatis
    (Offset(0.26, -0.06), Size(0.18, 0.13), 0.3), // Tranquillitatis
    (Offset(0.60, -0.26), Size(0.09, 0.08), 0.0), // Crisium
    (Offset(0.49, 0.16), Size(0.10, 0.14), 0.2), // Fecunditatis
    (Offset(0.30, 0.22), Size(0.08, 0.10), 0.0), // Nectaris
    (Offset(-0.12, 0.38), Size(0.16, 0.11), 0.1), // Nubium
    (Offset(-0.41, 0.35), Size(0.08, 0.08), 0.0), // Humorum
    (Offset(-0.04, -0.63), Size(0.36, 0.06), 0.0), // Frigoris
  ];

  // Bright ray craters: Tycho and Copernicus.
  static const List<(Offset, double)> _craters = [
    (Offset(-0.09, 0.68), 0.040),
    (Offset(-0.28, -0.16), 0.030),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final k = illumination;
    final disk = Rect.fromCircle(center: c, radius: r);

    if (halo) _paintHalo(canvas, c, r, k);

    canvas.save();
    if (southern) {
      // Seen from the south the Moon is rotated 180°.
      canvas.translate(c.dx, c.dy);
      canvas.rotate(pi);
      canvas.translate(-c.dx, -c.dy);
    }

    final diskPath = Path()..addOval(disk);
    canvas.saveLayer(disk.inflate(2), Paint());
    canvas.clipPath(diskPath);

    // Night side: the same surface, very dark, lit faintly by earthshine
    // (strongest for thin crescents).
    final earthshine = 0.10 + 0.22 * pow(1 - k, 3);
    _paintSurface(canvas, c, r, night: true, earthshine: earthshine.toDouble());

    // Day side, with the shadowed part erased through a soft terminator.
    // (Erasing the shadow, not keeping the lit part: a blend only touches
    // the pixels it draws.)
    canvas.saveLayer(disk.inflate(2), Paint());
    _paintSurface(canvas, c, r, night: false, earthshine: 0);
    final sigma = max(0.6, r * 0.045);
    final shadow = _shadowPath(c, r, k, rightSide: waxing, margin: sigma * 4);
    if (shadow != null) {
      canvas.drawPath(
        shadow,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
    canvas.restore();

    if (eclipse) {
      // Blood moon: sunlight refracted through Earth's atmosphere.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = const RadialGradient(
            center: Alignment(-0.25, -0.3),
            colors: [Color(0xFFFFB08A), Color(0xFFE0502E), Color(0xFF7A160C)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(disk),
      );
    }

    canvas.restore();

    canvas.drawCircle(
      c,
      r - max(0.5, r * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, r * 0.04)
        ..color = (eclipse ? const Color(0xFFFF6B4A) : const Color(0xFFFFFFFF))
            .withValues(alpha: 0.05 + 0.10 * k),
    );
    canvas.restore();
  }

  void _paintHalo(Canvas canvas, Offset c, double r, double k) {
    final strength = eclipse ? 0.75 : 0.05 + 0.40 * k * k;
    final color = eclipse ? const Color(0xFFFF4A2A) : const Color(0xFFDDE6F7);
    final rect = Rect.fromCircle(center: c, radius: r * 2.0);
    canvas.drawCircle(
      c,
      r * 2.0,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: strength),
            color.withValues(alpha: strength * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.45, 0.65, 1.0],
        ).createShader(rect),
    );
  }

  void _paintSurface(Canvas canvas, Offset c, double r,
      {required bool night, required double earthshine}) {
    final disk = Rect.fromCircle(center: c, radius: r);
    final base = night
        ? [
            Color.lerp(const Color(0xFF0E1118), const Color(0xFF3A4253), earthshine)!,
            Color.lerp(const Color(0xFF0A0C12), const Color(0xFF262C3A), earthshine)!,
          ]
        : const [Color(0xFFFBF8EF), Color(0xFFDADCE4), Color(0xFFAEB3C1)];
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.25),
          radius: 1.05,
          colors: base,
        ).createShader(disk),
    );

    final mariaColor = night
        ? const Color(0xFF05070B).withValues(alpha: 0.35 * earthshine * 3)
        : const Color(0xFF737B8E).withValues(alpha: 0.40);
    final blur = MaskFilter.blur(BlurStyle.normal, max(0.4, r * 0.06));
    for (final (center, radii, rot) in _maria) {
      canvas.save();
      canvas.translate(c.dx + center.dx * r, c.dy + center.dy * r);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: radii.width * 2 * r, height: radii.height * 2 * r),
        Paint()
          ..color = mariaColor
          ..maskFilter = blur,
      );
      canvas.restore();
    }

    if (!night && r >= 40) {
      // Fine cratering: fixed seed so the surface never changes.
      final rng = Random(7);
      for (var i = 0; i < 110; i++) {
        final a = rng.nextDouble() * 2 * pi;
        final d = sqrt(rng.nextDouble()) * 0.92;
        final p = Offset(c.dx + cos(a) * d * r, c.dy + sin(a) * d * r);
        final cr = r * (0.008 + pow(rng.nextDouble(), 3) * 0.035);
        canvas.drawCircle(
          p,
          cr,
          Paint()..color = const Color(0xFF5E6575).withValues(alpha: 0.10 + rng.nextDouble() * 0.10),
        );
        canvas.drawCircle(
          p.translate(-cr * 0.35, -cr * 0.35),
          cr * 0.7,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06 + rng.nextDouble() * 0.06),
        );
      }
    }

    if (!night && r >= 24) {
      for (final (center, rad) in _craters) {
        final p = Offset(c.dx + center.dx * r, c.dy + center.dy * r);
        // Faint ray system plus a soft bright floor, no hard dot.
        final rays = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07)
          ..strokeWidth = max(0.5, r * 0.012)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.01);
        for (var a = 0; a < 9; a++) {
          final ang = a * 0.7 + center.dx * 3;
          final len = r * (0.18 + 0.12 * ((a * 37) % 5) / 5);
          canvas.drawLine(p, p + Offset(cos(ang), sin(ang)) * len, rays);
        }
        canvas.drawCircle(
          p,
          rad * r,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.30)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * r * 0.5),
        );
      }
    }
  }

  /// The unlit part, extended past the limb on the dark side so the blurred
  /// edge doesn't leave a glowing rim there. Null when fully lit.
  static Path? _shadowPath(Offset c, double r, double k,
      {required bool rightSide, required double margin}) {
    if (k >= 0.995) return null;
    final big = Rect.fromCircle(center: c, radius: r + margin);
    final bigPath = Path()..addOval(big);
    if (k <= 0.005) return bigPath;
    final disk = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final litSide = rightSide
        ? Rect.fromLTRB(c.dx, big.top, big.right, big.bottom)
        : Rect.fromLTRB(big.left, big.top, c.dx, big.bottom);
    final litRing = Path.combine(
      PathOperation.intersect,
      Path.combine(PathOperation.difference, bigPath, disk),
      Path()..addRect(litSide),
    );
    final lit = Path.combine(
        PathOperation.union, _litPath(c, r, k, rightSide: rightSide), litRing);
    return Path.combine(PathOperation.difference, bigPath, lit);
  }

  /// Lit region for illuminated fraction [k], lit limb on the right (or left).
  /// The terminator is a half-ellipse whose half-width is |1 − 2k|·r.
  static Path litPath(Offset c, double r, double k, {required bool rightSide}) =>
      _litPath(c, r, k, rightSide: rightSide);

  static Path _litPath(Offset c, double r, double k, {required bool rightSide}) {
    final path = Path();
    if (k <= 0.001) return path;
    final disk = Rect.fromCircle(center: c, radius: r);
    if (k >= 0.999) return path..addOval(disk);

    final e = (1 - 2 * k) * r;
    path.moveTo(c.dx, c.dy - r);
    path.arcTo(disk, -pi / 2, pi, false);
    if (e.abs() < 0.01) {
      path.lineTo(c.dx, c.dy - r);
    } else {
      final ellipse = Rect.fromLTRB(c.dx - e.abs(), c.dy - r, c.dx + e.abs(), c.dy + r);
      // Crescent: the terminator bulges toward the lit limb; gibbous: away.
      path.arcTo(ellipse, pi / 2, e > 0 ? -pi : pi, false);
    }
    path.close();

    if (rightSide) return path;
    final mirror = Matrix4.identity()
      ..translateByDouble(c.dx, 0, 0, 1)
      ..scaleByDouble(-1, 1, 1, 1)
      ..translateByDouble(-c.dx, 0, 0, 1);
    return path.transform(mirror.storage);
  }

  @override
  bool shouldRepaint(MoonPainter old) =>
      (old.illumination * 1000).round() != (illumination * 1000).round() ||
      old.waxing != waxing ||
      old.southern != southern ||
      old.eclipse != eclipse ||
      old.halo != halo;
}
