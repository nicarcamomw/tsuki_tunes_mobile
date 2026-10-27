import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/moon_provider.dart';
import 'sakura_overlay.dart';
import 'witching_hour_overlay.dart';

/// Wraps the whole app: a light layer that follows tonight's real Moon (dark
/// and intimate at new moon, silver glow at full moon) and, during a real
/// lunar eclipse, blood-moon light with occasional glitches. Only light is
/// added on top: the app keeps its own colors.
class MoonAtmosphere extends StatelessWidget {
  final Widget child;

  const MoonAtmosphere({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final moon = context.watch<MoonProvider>();
    final eclipse = moon.eclipseActive;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (moon.atmosphereEnabled && !eclipse)
          IgnorePointer(
            child: MoonLightLayer(
              painter: MoonlightPainter(illumination: moon.snapshot.illumination),
              bakeKey: (moon.snapshot.illumination * 200).round(),
            ),
          ),
        if (eclipse) ...[
          const IgnorePointer(
            child: MoonLightLayer(painter: BloodMoonLightPainter(), bakeKey: 'blood'),
          ),
          if (!reduceMotion) const IgnorePointer(child: _GlitchBursts()),
        ],
        if (!reduceMotion) const IgnorePointer(child: SakuraOverlay()),
        if (!reduceMotion) const IgnorePointer(child: WitchingHourOverlay()),
      ],
    );
  }
}

/// Paints [painter] once into an image and shows that image. The light
/// layers are several full-screen gradients that only change a few times a
/// night; redrawing them every frame at 120 Hz cost real GPU time. Gradients
/// are smooth, so a logical-resolution image scaled up looks the same.
class MoonLightLayer extends StatefulWidget {
  final CustomPainter painter;
  /// Changes when the painter's output changes.
  final Object bakeKey;

  const MoonLightLayer({super.key, required this.painter, required this.bakeKey});

  @override
  State<MoonLightLayer> createState() => _MoonLightLayerState();
}

class _MoonLightLayerState extends State<MoonLightLayer> {
  ui.Image? _image;
  Size? _bakedSize;
  Object? _bakedKey;

  ui.Image? _bake(Size size) {
    if (size.isEmpty || !size.isFinite) return null;
    if (_image != null && size == _bakedSize && widget.bakeKey == _bakedKey) return _image;
    final recorder = ui.PictureRecorder();
    widget.painter.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
    picture.dispose();
    _image?.dispose();
    _image = image;
    _bakedSize = size;
    _bakedKey = widget.bakeKey;
    return image;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RepaintBoundary(
        child: RawImage(
          image: _bake(constraints.biggest),
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// Edge darkening shaped like the screen. A plain RadialGradient sizes its
/// radius from the shortest side, which on a tall phone would darken the
/// whole top and bottom, not just the edges.
void paintScreenVignette(Canvas canvas, Size size, Color color, {double start = 0.55}) {
  if (size.isEmpty) return;
  canvas.save();
  canvas.scale(1, size.height / size.width);
  final square = Rect.fromLTWH(0, 0, size.width, size.width);
  canvas.drawRect(
    square,
    Paint()
      ..shader = RadialGradient(
        radius: 0.75,
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0), color],
        stops: [0.0, start, 1.0],
      ).createShader(square),
  );
  canvas.restore();
}

/// Continuous with illumination, so every night looks slightly different.
class MoonlightPainter extends CustomPainter {
  final double illumination;

  MoonlightPainter({required this.illumination});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final k = illumination.clamp(0.0, 1.0);
    final dark = 1 - k;

    // New moon: the room goes darker.
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.10 * pow(dark, 1.5)),
    );

    paintScreenVignette(
        canvas, size, const Color(0xFF000000).withValues(alpha: 0.08 + 0.22 * dark));

    // Full moon: silver light falling from the top corner where the moon sits.
    if (k > 0.02) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.8, -1.1),
            radius: 1.2,
            colors: [
              const Color(0xFFD6E0F5).withValues(alpha: 0.14 * k * k),
              const Color(0xFFD6E0F5).withValues(alpha: 0.04 * k * k),
              const Color(0x00D6E0F5),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE6EEFF).withValues(alpha: 0.035 * k),
              const Color(0x00E6EEFF),
            ],
            stops: const [0.0, 0.4],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(MoonlightPainter old) =>
      (old.illumination * 200).round() != (illumination * 200).round();
}

/// The light of a blood moon: a crimson glow falling from the moon's corner,
/// a faint warm dusk over everything and deep red at the edges.
class BloodMoonLightPainter extends CustomPainter {
  const BloodMoonLightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = const Color(0xFF2A0306).withValues(alpha: 0.16));

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.8, -1.1),
          radius: 1.35,
          colors: [
            const Color(0xFFFF3B2A).withValues(alpha: 0.26),
            const Color(0xFFC81E1E).withValues(alpha: 0.10),
            const Color(0x00C81E1E),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect),
    );

    paintScreenVignette(canvas, size, const Color(0xFF3A0006).withValues(alpha: 0.55),
        start: 0.5);

    // A thin warm rim along the top, like light catching the glass.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFF4A2A).withValues(alpha: 0.10), const Color(0x00FF4A2A)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.18)),
    );
  }

  @override
  bool shouldRepaint(BloodMoonLightPainter old) => false;
}

/// Short, thin glitch bands every few seconds. Kept small and dim so they
/// never become a large-area flash.
class _GlitchBursts extends StatefulWidget {
  const _GlitchBursts();

  @override
  State<_GlitchBursts> createState() => _GlitchBurstsState();
}

class _GlitchBurstsState extends State<_GlitchBursts> {
  final _rng = Random();
  Timer? _next;
  Timer? _frame;
  List<_Band> _bands = const [];
  bool _showKanji = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _next = Timer(Duration(milliseconds: 4500 + _rng.nextInt(5500)), _burst);
  }

  void _burst() {
    if (!mounted) return;
    var frames = 2 + _rng.nextInt(3);
    _showKanji = _rng.nextDouble() < 0.3;
    void step() {
      if (!mounted) return;
      if (frames-- <= 0) {
        setState(() {
          _bands = const [];
          _showKanji = false;
        });
        _schedule();
        return;
      }
      setState(() {
        _bands = List.generate(1 + _rng.nextInt(3), (_) => _Band(
              y: _rng.nextDouble(),
              height: 1.5 + _rng.nextDouble() * 6,
              shift: (_rng.nextDouble() - 0.5) * 18,
              cyan: _rng.nextDouble() < 0.3,
              alpha: 0.08 + _rng.nextDouble() * 0.12,
            ));
      });
      _frame = Timer(const Duration(milliseconds: 120), step);
    }

    step();
  }

  @override
  void dispose() {
    _next?.cancel();
    _frame?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bands.isEmpty) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _GlitchPainter(_bands, _showKanji),
    );
  }
}

class _Band {
  final double y;
  final double height;
  final double shift;
  final bool cyan;
  final double alpha;

  const _Band({
    required this.y,
    required this.height,
    required this.shift,
    required this.cyan,
    required this.alpha,
  });
}

class _GlitchPainter extends CustomPainter {
  final List<_Band> bands;
  final bool kanji;

  _GlitchPainter(this.bands, this.kanji);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bands) {
      final color = b.cyan ? const Color(0xFF00E5FF) : const Color(0xFFFF1919);
      final top = b.y * size.height;
      canvas.drawRect(
        Rect.fromLTWH(b.shift, top, size.width, b.height),
        Paint()..color = color.withValues(alpha: b.alpha),
      );
      canvas.drawRect(
        Rect.fromLTWH(-b.shift, top + b.height, size.width, 1),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: b.alpha * 0.6),
      );
    }
    if (kanji) {
      final tp = TextPainter(
        text: TextSpan(
          text: '月食',
          style: TextStyle(
            fontSize: size.width * 0.38,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFF2A1A).withValues(alpha: 0.07),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, size.center(Offset(-tp.width / 2, -tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => true;
}
