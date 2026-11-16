import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'motion.dart';

/// 3:33 at night, with music playing: the witching hour. For a few seconds
/// the screen glitches, a kanji of the other side (鬼, 魂, 闇…) surfaces, a
/// line in the Lore's voice is whispered ("The hour the veil wears thin…")
/// and the phone beats like a heart.
///
/// With less motion asked for there's no glitch and no shaking kanji: it
/// fades in still and goes. The whisper is announced to TalkBack.
class WitchingHourOverlay extends ConsumerStatefulWidget {
  const WitchingHourOverlay({super.key, this.clock = DateTime.now});

  /// Stands in for the time (tests).
  final DateTime Function() clock;

  static const hour = 3;
  static const minute = 33;

  /// How long the moment lasts.
  static const Duration length = Duration(milliseconds: 4200);

  static const kanji = ['鬼', '魂', '闇', '呪', '死', '影', '夢', '幽'];

  @override
  ConsumerState<WitchingHourOverlay> createState() => _WitchingHourOverlayState();
}

class _WitchingHourOverlayState extends ConsumerState<WitchingHourOverlay> with SingleTickerProviderStateMixin {
  final _rng = Random();
  Timer? _pollTimer;
  bool _active = false;
  bool _still = false;
  bool _triggered = false;

  late final AnimationController _anim = AnimationController(vsync: this, duration: WitchingHourOverlay.length);
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1), weight: 63),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 25),
  ]).animate(_anim);

  List<_GlitchLine> _lines = const [];
  String _kanji = '';
  double _kanjiX = 0;
  double _kanjiY = 0;
  Timer? _glitchTimer;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _glitchTimer?.cancel();
        setState(() {
          _active = false;
          _lines = const [];
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTime());
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkTime());
  }

  void _checkTime() {
    if (!mounted) return;
    final now = widget.clock();
    final isWitchingMinute = now.hour == WitchingHourOverlay.hour && now.minute == WitchingHourOverlay.minute;
    if (isWitchingMinute && !_triggered && ref.read(audioProvider).isPlaying) {
      _triggered = true;
      _start();
    }
    if (!isWitchingMinute) _triggered = false;
  }

  void _start() {
    _still = reduceMotion(context);
    _kanji = WitchingHourOverlay.kanji[_rng.nextInt(WitchingHourOverlay.kanji.length)];
    _kanjiX = _still ? 0.5 : 0.2 + _rng.nextDouble() * 0.6;
    _kanjiY = _still ? 0.38 : 0.25 + _rng.nextDouble() * 0.3;
    Haptics.heartbeat();
    // A second beat as the whisper settles.
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _active) Haptics.heartbeat();
    });
    setState(() => _active = true);
    _anim.forward(from: 0);
    if (!_still) _tickGlitch();
  }

  void _tickGlitch() {
    if (!mounted || !_active) return;
    setState(() {
      _lines = List.generate(
        2 + _rng.nextInt(4),
        (_) => _GlitchLine(
          y: _rng.nextDouble(),
          height: 1.0 + _rng.nextDouble() * 3.0,
          shift: (_rng.nextDouble() - 0.5) * 12,
          cyan: _rng.nextBool(),
          alpha: 0.04 + _rng.nextDouble() * 0.08,
        ),
      );
    });
    _glitchTimer = Timer(Duration(milliseconds: 80 + _rng.nextInt(60)), _tickGlitch);
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
    final locale = ref.watch(localeProvider);
    final whisper = locale.strings.witchingWhisper;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
      // Over the whole app, above its pages: its own (clear) material.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _WitchingPainter(
                  lines: _lines,
                  kanji: _kanji,
                  kanjiX: _kanjiX,
                  kanjiY: _kanjiY,
                  jitter: _still ? Offset.zero : Offset((_rng.nextDouble() - 0.5) * 4, (_rng.nextDouble() - 0.5) * 4),
                ),
              ),
            ),
            // The whisper, low on the screen, in the Lore's voice.
            Align(
              alignment: const Alignment(0, 0.42),
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  label: whisper,
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        whisper,
                        textAlign: TextAlign.center,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w600,
                          color: AppColors.loreBody,
                          letterSpacing: 1.2,
                          shadows: const [Shadow(color: AppColors.ink, blurRadius: 12)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlitchLine {
  final double y;
  final double height;
  final double shift;
  final bool cyan;
  final double alpha;

  const _GlitchLine({required this.y, required this.height, required this.shift, required this.cyan, required this.alpha});
}

class _WitchingPainter extends CustomPainter {
  final List<_GlitchLine> lines;
  final String kanji;
  final double kanjiX;
  final double kanjiY;
  final Offset jitter;

  _WitchingPainter({required this.lines, required this.kanji, required this.kanjiX, required this.kanjiY, required this.jitter});

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      final color = l.cyan ? AppColors.neonCyan : AppColors.accent;
      canvas.drawRect(Rect.fromLTWH(l.shift, l.y * size.height, size.width, l.height), Paint()..color = color.withValues(alpha: l.alpha));
    }
    final fontSize = size.width * 0.22;
    final c = Offset(kanjiX * size.width, kanjiY * size.height) + jitter;
    if (jitter != Offset.zero) {
      // Split colour, only while it shakes.
      _drawKanji(canvas, fontSize, c + const Offset(-2.5, 0), AppColors.neonCyan.withValues(alpha: 0.06));
      _drawKanji(canvas, fontSize, c + const Offset(2.5, 0), AppColors.neonPurple.withValues(alpha: 0.05));
    }
    _drawKanji(canvas, fontSize, c, AppColors.accent.withValues(alpha: 0.10));
  }

  void _drawKanji(Canvas canvas, double fontSize, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: kanji,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_WitchingPainter old) => true;
}
