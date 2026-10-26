import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/moon_provider.dart';

/// Wraps the whole app: a light layer that follows tonight's real Moon (dark
/// and intimate at new moon, silver glow at full moon) and, during a real
/// lunar eclipse, turns everything blood red with occasional glitches.
class MoonAtmosphere extends StatefulWidget {
  final Widget child;

  const MoonAtmosphere({super.key, required this.child});

  @override
  State<MoonAtmosphere> createState() => _MoonAtmosphereState();
}

class _MoonAtmosphereState extends State<MoonAtmosphere> {
  // Keeps the navigator's state when the eclipse filter is added or removed.
  final GlobalKey _appKey = GlobalKey();

  // Luminance pushed into the red channel; green and blue mostly crushed.
  static const List<double> _bloodMatrix = [
    0.80, 0.75, 0.30, 0, 14,
    0.20, 0.17, 0.06, 0, 0,
    0.13, 0.11, 0.04, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final moon = context.watch<MoonProvider>();
    final eclipse = moon.eclipseActive;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget app = KeyedSubtree(key: _appKey, child: widget.child);
    if (eclipse) {
      app = ColorFiltered(colorFilter: const ColorFilter.matrix(_bloodMatrix), child: app);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        app,
        if (moon.atmosphereEnabled && !eclipse)
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MoonlightPainter(illumination: moon.snapshot.illumination),
              ),
            ),
          ),
        if (eclipse) ...[
          const IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _EclipseVeilPainter())),
          ),
          if (!reduceMotion) const IgnorePointer(child: _GlitchBursts()),
        ],
      ],
    );
  }
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

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.25,
          colors: [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0xFF000000).withValues(alpha: 0.08 + 0.22 * dark),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

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

class _EclipseVeilPainter extends CustomPainter {
  const _EclipseVeilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 1.2,
          colors: [Color(0x00000000), Color(0x22300000), Color(0x995A0000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    final scan = Paint()..color = const Color(0x0F000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
  }

  @override
  bool shouldRepaint(_EclipseVeilPainter old) => false;
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
    _next = Timer(Duration(milliseconds: 2200 + _rng.nextInt(3800)), _burst);
  }

  void _burst() {
    if (!mounted) return;
    var frames = 3 + _rng.nextInt(3);
    _showKanji = _rng.nextDouble() < 0.35;
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
        _bands = List.generate(2 + _rng.nextInt(4), (_) => _Band(
              y: _rng.nextDouble(),
              height: 2 + _rng.nextDouble() * 10,
              shift: (_rng.nextDouble() - 0.5) * 24,
              cyan: _rng.nextBool(),
              alpha: 0.12 + _rng.nextDouble() * 0.18,
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
            color: const Color(0xFFFF2A1A).withValues(alpha: 0.10),
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
