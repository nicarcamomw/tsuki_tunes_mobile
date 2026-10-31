import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

const _kWitchingHour = 3;
const _kWitchingMinute = 33;

const _kKanji = ['鬼', '魂', '闇', '呪', '死', '影', '夢', '幽'];

class WitchingHourOverlay extends ConsumerStatefulWidget {
  const WitchingHourOverlay({super.key});

  @override
  ConsumerState<WitchingHourOverlay> createState() => _WitchingHourOverlayState();
}

class _WitchingHourOverlayState extends ConsumerState<WitchingHourOverlay>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  Timer? _pollTimer;
  bool _active = false;
  bool _triggered = false;

  late final AnimationController _anim;
  late Animation<double> _opacity;

  List<_GlitchLine> _lines = const [];
  String _kanji = '';
  double _kanjiX = 0;
  double _kanjiY = 0;
  Timer? _glitchTimer;
  int _glitchFrame = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 72),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_anim);
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _active = false;
          _lines = const [];
        });
      }
    });
    _checkTime();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkTime());
  }

  void _checkTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final isWitchingMinute =
        now.hour == _kWitchingHour && now.minute == _kWitchingMinute;

    if (isWitchingMinute && !_triggered) {
      final audio = ref.read(audioProvider);
      if (audio.isPlaying) {
        _triggered = true;
        _startEffect();
      }
    }

    if (!isWitchingMinute) {
      _triggered = false;
    }
  }

  void _startEffect() {
    _kanji = _kKanji[_rng.nextInt(_kKanji.length)];
    _kanjiX = 0.15 + _rng.nextDouble() * 0.7;
    _kanjiY = 0.2 + _rng.nextDouble() * 0.5;
    _glitchFrame = 0;
    setState(() => _active = true);
    _anim.forward(from: 0);
    _tickGlitch();
  }

  void _tickGlitch() {
    if (!mounted || !_active) return;
    _glitchFrame++;
    setState(() {
      _lines = List.generate(2 + _rng.nextInt(4), (_) {
        return _GlitchLine(
          y: _rng.nextDouble(),
          height: 1.0 + _rng.nextDouble() * 3.0,
          shift: (_rng.nextDouble() - 0.5) * 12,
          isCyan: _rng.nextBool(),
          alpha: 0.04 + _rng.nextDouble() * 0.08,
        );
      });
    });
    _glitchTimer = Timer(
      Duration(milliseconds: 80 + _rng.nextInt(60)),
      _tickGlitch,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _glitchTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: CustomPaint(
            size: Size.infinite,
            painter: _WitchingPainter(
              lines: _lines,
              kanji: _kanji,
              kanjiX: _kanjiX,
              kanjiY: _kanjiY,
              frame: _glitchFrame,
              rng: _rng,
            ),
          ),
        );
      },
    );
  }
}

class _GlitchLine {
  final double y;
  final double height;
  final double shift;
  final bool isCyan;
  final double alpha;

  const _GlitchLine({
    required this.y,
    required this.height,
    required this.shift,
    required this.isCyan,
    required this.alpha,
  });
}

class _WitchingPainter extends CustomPainter {
  final List<_GlitchLine> lines;
  final String kanji;
  final double kanjiX;
  final double kanjiY;
  final int frame;
  final Random rng;

  _WitchingPainter({
    required this.lines,
    required this.kanji,
    required this.kanjiX,
    required this.kanjiY,
    required this.frame,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final color = l.isCyan
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFF1919);
      final top = l.y * size.height;
      canvas.drawRect(
        Rect.fromLTWH(l.shift, top, size.width, l.height),
        Paint()..color = color.withValues(alpha: l.alpha),
      );
    }

    final fontSize = size.width * 0.22;
    final cx = kanjiX * size.width;
    final cy = kanjiY * size.height;

    final jitterX = (rng.nextDouble() - 0.5) * 4;
    final jitterY = (rng.nextDouble() - 0.5) * 4;

    // Cyan shadow offset left
    _drawKanji(canvas, kanji, fontSize, cx - 2.5 + jitterX, cy + jitterY,
        const Color(0xFF00E5FF).withValues(alpha: 0.06));

    // Magenta shadow offset right
    _drawKanji(canvas, kanji, fontSize, cx + 2.5 + jitterX, cy + jitterY,
        const Color(0xFFB026FF).withValues(alpha: 0.05));

    // Main red glow
    _drawKanji(canvas, kanji, fontSize, cx + jitterX, cy + jitterY,
        const Color(0xFFFF1919).withValues(alpha: 0.09));
  }

  void _drawKanji(
      Canvas canvas, String text, double fontSize, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_WitchingPainter old) => true;
}
