import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A tinted card with soft blots of color inside, like ink spreading in
/// water. The blots bloom one after another when the card appears and then
/// stay still: nothing is redrawn afterwards, so a screen full of cards
/// costs nothing while it sits there.
class GlassCard extends StatefulWidget {
  final Color color;
  final double highlightAlpha;
  final double dimAlpha;
  final double borderAlpha;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Widget child;

  /// Fixes where the blots fall, which is otherwise different every time
  /// (golden tests need the same picture each run).
  final int? seed;

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
    @visibleForTesting this.seed,
  });

  /// How long the blots take to bloom when the card appears.
  static const Duration bloomDuration = Duration(milliseconds: 1400);

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  late final AnimationController _bloom =
      AnimationController(vsync: this, duration: GlassCard.bloomDuration);
  late final _InkBlots _blots =
      _InkBlots(widget.seed ?? Random().nextInt(1 << 31));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _bloom.value = 1;
    } else {
      _bloom.forward();
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    _blots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    Widget card = RepaintBoundary(
      child: CustomPaint(
        painter: _CardPainter(
          color: widget.color,
          highlightAlpha: widget.highlightAlpha,
          dimAlpha: widget.dimAlpha,
          borderAlpha: widget.borderAlpha,
          borderRadius: widget.borderRadius,
          blots: _blots,
          bloom: _bloom,
          dpr: dpr,
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
    if (widget.margin != null) card = Padding(padding: widget.margin!, child: card);
    return card;
  }
}

/// One blot: an irregular rounded shape, blurred, baked once into an image.
class _Blot {
  final Offset center; // fraction of the card
  final double radius; // fraction of the card's longest side
  final double start; // when it starts blooming, fraction of the bloom
  final bool second; // painted in the shifted hue
  final List<double> wobble; // radius factor per control point

  const _Blot(this.center, this.radius, this.start, this.second, this.wobble);
}

/// A card's blots and their baked images.
class _InkBlots {
  final List<_Blot> blots;
  final Map<int, ui.Image> _images = {};
  Object? _bakedFor;

  _InkBlots(int seed) : blots = _make(Random(seed));

  static List<_Blot> _make(Random rng) {
    // Big soft blot near a corner, a mid one across from it and a small
    // bright one: reads as depth, never as a pattern.
    final corner = rng.nextBool();
    final spots = [
      (Offset(corner ? 0.1 : 0.9, 0.1 + rng.nextDouble() * 0.3), 0.5, 0.0, false),
      (Offset(corner ? 0.78 : 0.22, 0.7 + rng.nextDouble() * 0.3), 0.4, 0.18, true),
      (Offset(0.4 + rng.nextDouble() * 0.25, rng.nextDouble()), 0.24, 0.38, false),
      if (rng.nextDouble() < 0.6)
        (Offset(rng.nextDouble(), rng.nextDouble()), 0.16, 0.5, true),
    ];
    return [
      for (final (c, r, s, second) in spots)
        _Blot(c, r * (0.85 + rng.nextDouble() * 0.3), s, second,
            [for (var i = 0; i < 7; i++) 0.72 + rng.nextDouble() * 0.5]),
    ];
  }

  /// The blot's image, baked for [key] (card size, colors, density).
  ui.Image imageFor(int index, Object key, double sizePx, Color color) {
    if (_bakedFor != key) {
      dispose();
      _bakedFor = key;
    }
    return _images[index] ??= _bake(blots[index], sizePx, color);
  }

  static ui.Image _bake(_Blot blot, double sizePx, Color color) {
    final px = sizePx.ceil().clamp(2, 1024);
    final c = Offset(px / 2, px / 2);
    // The shape fills ~60% of the image so the blur fades out inside it.
    final r = px * 0.3;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawPath(
      _shape(c, r, blot.wobble),
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: color.a * 0.55)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.38),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(px, px);
    picture.dispose();
    return image;
  }

  /// A smooth closed curve through points around [c] (Catmull-Rom as
  /// cubic Béziers), so the blot is organic rather than a circle.
  static Path _shape(Offset c, double r, List<double> wobble) {
    final n = wobble.length;
    final pts = [
      for (var i = 0; i < n; i++)
        c + Offset.fromDirection(i * 2 * pi / n, r * wobble[i]),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}

class _CardPainter extends CustomPainter {
  final Color color;
  final double highlightAlpha;
  final double dimAlpha;
  final double borderAlpha;
  final double borderRadius;
  final _InkBlots blots;
  final Animation<double> bloom;
  final double dpr;

  _CardPainter({
    required this.color,
    required this.highlightAlpha,
    required this.dimAlpha,
    required this.borderAlpha,
    required this.borderRadius,
    required this.blots,
    required this.bloom,
    required this.dpr,
  }) : super(repaint: bloom);

  /// The card's color turned around the color wheel, for the second tone.
  Color get _shifted {
    final hsv = HSVColor.fromColor(color);
    return hsv.withHue((hsv.hue + 38) % 360).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final bg = AppColors.bgCard;

    canvas.save();
    canvas.clipRRect(rrect);

    // Base: the card tinted from the top-left corner.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(color.withValues(alpha: highlightAlpha * 0.6), bg),
            bg,
            Color.alphaBlend(color.withValues(alpha: dimAlpha), bg),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    // Blots: each grows from a drop and fades in, one after another.
    // Sized by the card's area: on a wide, short card blots sized by its
    // length would flood it.
    final unit = sqrt(size.width * size.height);
    final strength = (highlightAlpha * 2.6).clamp(0.16, 0.48);
    final key = (size, dpr, color, _shifted, strength);
    final t = bloom.value;
    for (var i = 0; i < blots.blots.length; i++) {
      final b = blots.blots[i];
      final local = ((t - b.start) / (1 - b.start)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final grow = Curves.easeOutCubic.transform(local);
      final side = unit * b.radius * 2 / 0.6; // the shape is 60% of the image
      final image = blots.imageFor(
        i,
        key,
        side * dpr,
        (b.second ? _shifted : color).withValues(alpha: strength * (b.second ? 0.8 : 1)),
      );
      final drawn = side * (0.45 + 0.55 * grow);
      final center = Offset(b.center.dx * size.width, b.center.dy * size.height);
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: center, width: drawn, height: drawn),
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Color.fromRGBO(255, 255, 255, Curves.easeOut.transform(local)),
      );
    }

    // A faint highlight along the top, like light on glass.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.045), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
    );
    canvas.restore();

    // Rim: the card's color, brighter along the top edge.
    canvas.drawRRect(
      rrect.deflate(0.5),
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
  bool shouldRepaint(_CardPainter old) =>
      old.color != color ||
      old.highlightAlpha != highlightAlpha ||
      old.dimAlpha != dimAlpha ||
      old.borderAlpha != borderAlpha ||
      old.borderRadius != borderRadius ||
      old.blots != blots ||
      old.dpr != dpr;
}
