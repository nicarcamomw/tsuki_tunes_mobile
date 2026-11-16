import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'connection_notice.dart';
import 'frosted_glass.dart';
import 'haptics.dart';
import 'motion.dart';

/// The user's birthday: the first time Tsuki opens that day, a short rain
/// of sakura falls over the app ([burst], about 12 s) under a glass pill
/// that says "Happy birthday"; tapping the pill brings the rain again.
///
/// The petals repaint through a listenable (nothing rebuilds), and once
/// they've fallen the ticker stops: no cost the rest of the day. With less
/// motion asked for, the greeting comes alone.
class SakuraOverlay extends ConsumerStatefulWidget {
  const SakuraOverlay({super.key, this.today});

  /// Stands in for the date (tests).
  final DateTime? today;

  static const birthdayKey = 'tsuki_birthday';
  static const shownKey = 'tsuki_birthday_shown';

  /// How long a rain lasts, its last petals included.
  static const Duration burst = Duration(seconds: 12);

  /// How long the greeting stays after the rain.
  static const Duration greetingAfter = Duration(seconds: 4);

  @override
  ConsumerState<SakuraOverlay> createState() => _SakuraOverlayState();
}

class _SakuraOverlayState extends ConsumerState<SakuraOverlay> with SingleTickerProviderStateMixin {
  static const _petalCount = 34;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _time = ValueNotifier(0);
  final _rng = Random();
  List<_Petal> _petals = const [];
  bool _raining = false;
  bool _greeting = false;
  Timer? _hideGreeting;

  @override
  void initState() {
    super.initState();
    unawaited(_checkBirthday());
  }

  Future<void> _checkBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    final birthday = prefs.getString(SakuraOverlay.birthdayKey);
    if (birthday == null || !mounted) return;
    final parts = birthday.split('-');
    if (parts.length != 2) return;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final now = widget.today ?? DateTime.now();
    if (month != now.month || day != now.day) return;
    // Once a day: the first time Tsuki opens.
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (prefs.getString(SakuraOverlay.shownKey) == todayKey) return;
    await prefs.setString(SakuraOverlay.shownKey, todayKey);
    if (mounted) _celebrate();
  }

  void _celebrate() {
    Haptics.success();
    _hideGreeting?.cancel();
    setState(() => _greeting = true);
    if (reduceMotion(context)) {
      _hideGreeting = Timer(SakuraOverlay.greetingAfter * 2, _endGreeting);
      return;
    }
    _petals = List.generate(_petalCount, (_) => _Petal.random(_rng));
    _time.value = 0;
    setState(() => _raining = true);
    if (_ticker.isActive) _ticker.stop();
    unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (t >= SakuraOverlay.burst.inSeconds) {
      _ticker.stop();
      setState(() {
        _raining = false;
        _petals = const [];
      });
      _hideGreeting = Timer(SakuraOverlay.greetingAfter, _endGreeting);
      return;
    }
    _time.value = t;
  }

  void _endGreeting() {
    if (mounted) setState(() => _greeting = false);
  }

  @override
  void dispose() {
    _hideGreeting?.cancel();
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    // Over the whole app, above its pages: its own (clear) material.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_raining)
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(size: Size.infinite, painter: _SakuraPainter(_petals, _time)),
              ),
            ),
          // The greeting, at the top (below the connection pill if it's there).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: ValueListenableBuilder<bool>(
                valueListenable: ConnectionNotice.visible,
                builder: (context, pill, child) => Padding(
                  padding: EdgeInsets.only(top: 8 + (pill ? ConnectionNotice.clearance : 0)),
                  child: child,
                ),
                child: Center(
                  child: AnimatedSlide(
                    duration: AppMotion.normal,
                    curve: _greeting ? AppMotion.enter : AppMotion.exit,
                    offset: _greeting ? Offset.zero : const Offset(0, -1.8),
                    child: AnimatedOpacity(
                      duration: AppMotion.normal,
                      opacity: _greeting ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_greeting,
                        child: Semantics(
                          liveRegion: _greeting,
                          button: true,
                          label: locale.strings.birthdayGreeting,
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              onTap: _celebrate,
                              child: FrostedGlass(
                                color: AppColors.inkPanel,
                                fill: AppGlass.fill,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.sakura.withValues(alpha: 0.6)),
                                shadowColor: AppColors.sakura.withValues(alpha: 0.3),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.cake_rounded, size: 18, color: AppColors.sakura),
                                      const SizedBox(width: 8),
                                      Text(
                                        locale.strings.birthdayGreeting,
                                        style: locale.getTextStyle(
                                          fontSize: AppFontSize.bodyLg,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textBright,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Petal {
  final double x;
  final double delay;
  final double size;
  final double fall;
  final double drift;
  final double wobblePhase;
  final double wobbleAmp;
  final double rotation;
  final double rotSpeed;
  final double alpha;

  const _Petal({
    required this.x,
    required this.delay,
    required this.size,
    required this.fall,
    required this.drift,
    required this.wobblePhase,
    required this.wobbleAmp,
    required this.rotation,
    required this.rotSpeed,
    required this.alpha,
  });

  /// Each falls once, from above the screen to below it, starting within
  /// the first half of the rain so all have landed by its end.
  factory _Petal.random(Random rng) => _Petal(
    x: rng.nextDouble(),
    delay: rng.nextDouble() * 5.5,
    size: 7 + rng.nextDouble() * 7,
    fall: 4.5 + rng.nextDouble() * 2,
    drift: (rng.nextDouble() - 0.5) * 0.12,
    wobblePhase: rng.nextDouble() * pi * 2,
    wobbleAmp: 10 + rng.nextDouble() * 18,
    rotation: rng.nextDouble() * pi * 2,
    rotSpeed: 0.5 + rng.nextDouble() * 1.2,
    alpha: 0.45 + rng.nextDouble() * 0.4,
  );
}

/// Sakura petals: a rounded petal with the notch at its tip, pink deepening
/// toward the base, turning as it falls.
class _SakuraPainter extends CustomPainter {
  _SakuraPainter(this.petals, this.time) : super(repaint: time);

  final List<_Petal> petals;
  final ValueNotifier<double> time;

  static Path _petal(double s) {
    final w = s * 0.62;
    return Path()
      ..moveTo(0, s * 0.5)
      ..cubicTo(-w, s * 0.2, -w * 0.8, -s * 0.45, -s * 0.12, -s * 0.5)
      // The notch.
      ..lineTo(0, -s * 0.36)
      ..lineTo(s * 0.12, -s * 0.5)
      ..cubicTo(w * 0.8, -s * 0.45, w, s * 0.2, 0, s * 0.5)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final p in petals) {
      final life = (t - p.delay) / p.fall;
      if (life <= 0 || life >= 1) continue;
      final y = -0.08 + life * 1.16;
      final wobble = sin(t * 1.4 + p.wobblePhase) * p.wobbleAmp;
      final px = (p.x + p.drift * life) * size.width + wobble;
      // Fades in at the top and out at the bottom.
      final fade = min(1.0, min(life * 6, (1 - life) * 6));
      canvas
        ..save()
        ..translate(px, y * size.height)
        ..rotate(p.rotation + p.rotSpeed * t)
        // Turning in the air: narrower as it shows its edge.
        ..scale(0.55 + 0.45 * cos(t * p.rotSpeed + p.wobblePhase).abs(), 1);
      final path = _petal(p.size);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(AppColors.sakura, Colors.white, 0.55)!.withValues(alpha: p.alpha * fade),
              AppColors.sakura.withValues(alpha: p.alpha * fade),
            ],
          ).createShader(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SakuraPainter old) => old.petals != petals;
}
