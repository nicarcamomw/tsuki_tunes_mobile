import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/session_gate.dart';
import '../state/app_providers.dart';
import '../widgets/motion.dart';

/// The entrance, while the session wakes up (auth, the tutorial flag).
///
/// It carries on Android's splash without a seam (the same night, the same
/// mask at the same size and place, the glow the animated splash ended
/// with), then plays the "Eclipse": a crimson nebula drifts in behind (a
/// GPU shader), a line of light scans the mask, the signal glitches once,
/// a moon ring draws itself around it and the name types itself under it.
/// When the session is ready the mask blooms into the next screen. It never
/// holds the app back: everything plays while waking, and leaving is
/// immediate. With less motion asked for, it's the still mask and ring.
///
/// Light on purpose: the intro's clock and one continuous time (a ticker
/// that never wraps, so nothing jumps however long it waits), painters
/// that repaint without rebuilding, effects that exist only while they
/// play, and the mask and the shader loaded while Firebase starts
/// ([warmUp]).
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  /// The mask's width: as large as in Android 12's splash (on its 288 dp
  /// icon, the mask is 552 of the logo's 1024 px tall; see
  /// tool/splash/make_glow_frames.py), so the hand-over is exact.
  static const double maskWidth = 109.12;

  /// The glow the animated splash ends with: the first frame picks it up.
  static const double splashGlowRadius = 93;
  static const double splashGlowAlpha = 0.20;

  /// How long before the line at the bottom says waking takes a moment.
  static const Duration patience = Duration(milliseconds: 1600);

  /// The intro's length (everything but the slow loop).
  static const Duration intro = Duration(milliseconds: 1600);

  /// The entrance's mask (by the app's author), cut out of its background
  /// by tool/mask_art/cut_out.py.
  static const String maskAsset = 'assets/images/tsuki_mask.webp';
  static const String nebulaAsset = 'shaders/tsuki_nebula.frag';

  /// The nebula's program, loaded once (null where shaders can't load: the
  /// screen then keeps its plain night).
  static final Future<ui.FragmentProgram?> nebula = ui.FragmentProgram.fromAsset(
    nebulaAsset,
  ).then<ui.FragmentProgram?>((p) => p).catchError((Object _) => null);

  /// Starts decoding the mask and compiling the nebula before the first
  /// frame (called from main, while Firebase starts), so the mask is there
  /// on the very first frame instead of popping in a frame later.
  static void warmUp() {
    const AssetImage(maskAsset).resolve(ImageConfiguration.empty);
    unawaited(nebula);
  }

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

/// A slow breath (0..1) every 2.8 s, from the continuous time.
double _breathAt(double t) => 0.5 - 0.5 * math.cos(2 * math.pi * t / 2.8);

class _LoadingScreenState extends ConsumerState<LoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: LoadingScreen.intro);
  late final AnimationController _exit = AnimationController(vsync: this, duration: AppMotion.normal);
  // Seconds since the screen opened: the nebula, the breath, the ring's turn
  // and the embers all read it. It never wraps, so nothing ever jumps.
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);
  ui.FragmentShader? _shader;
  Timer? _patience;
  bool _slow = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _patience = Timer(LoadingScreen.patience, () {
      if (mounted) setState(() => _slow = true);
    });
    unawaited(
      LoadingScreen.nebula.then((program) {
        if (!mounted || program == null) return;
        setState(() => _shader = program.fragmentShader());
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _intro.value = 1;
      if (_ticker.isActive) _ticker.stop();
    } else {
      if (!_started) {
        _started = true;
        unawaited(_intro.forward());
      }
      if (!_ticker.isActive) unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _patience?.cancel();
    _ticker.dispose();
    _time.dispose();
    _intro.dispose();
    _exit.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Animation<double> _part(double begin, double end, [Curve curve = Curves.linear]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    // Ready: bloom into the next screen (it fades in over this one).
    ref.listen<SessionStatus>(sessionGateProvider.select((g) => g.status), (_, status) {
      if (status != SessionStatus.loading && !reduceMotion(context)) unawaited(_exit.forward());
    });
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final still = reduceMotion(context);

    final sky = _part(0, 0.4, Curves.easeOut);
    final glowIn = _part(0, 0.3, AppMotion.enter);
    final scan = _part(0.15, 0.65, Curves.easeInOutCubic);
    final ring = _part(0.2, 0.85, Curves.easeInOutCubic);
    final pulse = _part(0.82, 1, Curves.easeOutCubic);
    final ticks = _part(0.7, 1, AppMotion.enter);
    final type = _part(0.35, 0.85);
    final exit = CurvedAnimation(parent: _exit, curve: AppMotion.exit);
    const mask = _Mask();

    return Scaffold(
      backgroundColor: AppColors.splash,
      body: Semantics(
        label: strings.a11yLoading,
        liveRegion: true,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The nebula, on the GPU; repaints without rebuilding.
              if (_shader != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _NebulaPainter(_shader!, time: _time, intensity: sky, still: still),
                    ),
                  ),
                ),
              // A few embers rising slowly through it.
              if (!still)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _EmbersPainter(time: _time, intensity: sky, exit: exit),
                    ),
                  ),
                ),
              // The red glow behind the mask, breathing, and its shadow.
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(300),
                  painter: _GlowPainter(grow: glowIn, time: _time, exit: exit, still: still),
                ),
              ),
              // The moon ring, drawing itself, then turning slowly.
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(320),
                  painter: _RingPainter(sweep: ring, pulse: pulse, ticks: ticks, time: _time, exit: exit, still: still),
                ),
              ),
              // The mask: breath, scan and glitch.
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _time, _exit]),
                  child: mask,
                  builder: (context, mask) {
                    final breath = still ? 0.0 : _breathAt(_time.value);
                    final scale = (1 + 0.025 * breath) * (1 + 0.12 * exit.value);
                    final scanning = !still && _intro.value > 0.15 && _intro.value < 0.65;
                    final glitch = !still && _intro.value > 0.55 && _intro.value < 0.72 ? _intro.value : null;
                    Widget out = mask!;
                    if (scanning) out = _Scan(progress: scan.value, child: out);
                    if (glitch != null) out = _Glitch(seed: glitch, child: out);
                    return Opacity(
                      opacity: 1 - exit.value,
                      child: Transform.scale(scale: scale, child: out),
                    );
                  },
                ),
              ),
              // The name, typing itself under the ring.
              Positioned(
                top: MediaQuery.sizeOf(context).height / 2 + 150,
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([type, _exit]),
                    builder: (context, _) {
                      const name = 'TSUKI TUNES';
                      final shown = (name.length * type.value).round();
                      return Opacity(
                        opacity: 1 - exit.value,
                        child: Text(
                          name.substring(0, shown).padRight(name.length),
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 6,
                            tabular: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // At the bottom, only if waking takes a moment.
              Positioned(
                left: 32,
                right: 32,
                bottom: MediaQuery.paddingOf(context).bottom + 56,
                child: AnimatedOpacity(
                  opacity: _slow ? 1 : 0,
                  duration: AppMotion.slow,
                  curve: AppMotion.enter,
                  child: ExcludeSemantics(
                    child: Text(
                      strings.loadingWaking,
                      textAlign: TextAlign.center,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mask extends StatelessWidget {
  const _Mask();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Image(
      image: AssetImage(LoadingScreen.maskAsset),
      width: LoadingScreen.maskWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    ),
  );
}

/// A band of crimson light crossing the mask, only on its own pixels, with
/// a thin white core at its edge.
class _Scan extends StatelessWidget {
  const _Scan({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcATop,
    shaderCallback: (bounds) {
      final y = -0.2 + 1.4 * progress;
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [(y - 0.10).clamp(0, 1), (y - 0.006).clamp(0, 1), y.clamp(0, 1), (y + 0.006).clamp(0, 1)],
        colors: [
          AppColors.accent.withValues(alpha: 0),
          AppColors.accent.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(bounds);
    },
    child: child,
  );
}

/// The signal slipping once: horizontal slices of the mask jumping
/// sideways over red and cyan ghosts, three jumps in 270 ms.
class _Glitch extends StatelessWidget {
  const _Glitch({required this.seed, required this.child});

  final double seed;
  final Widget child;

  static const _slices = [(0.0, 0.38), (0.38, 0.56), (0.56, 1.0)];
  static const _shifts = [
    [0.0, 6.0, -1.0],
    [-4.0, 0.0, 3.0],
    [1.5, -2.5, 0.0],
  ];

  @override
  Widget build(BuildContext context) {
    final step = ((seed - 0.55) / 0.17 * 3).floor().clamp(0, 2);
    final dx = const [3.0, -2.0, 1.5][step];
    Widget ghost(Color color, double x) => Transform.translate(
      offset: Offset(x, 0),
      child: Image(
        image: const AssetImage(LoadingScreen.maskAsset),
        width: LoadingScreen.maskWidth,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        gaplessPlayback: true,
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        ghost(AppColors.accent.withValues(alpha: 0.55), dx),
        ghost(AppColors.neonCyan.withValues(alpha: 0.35), -dx),
        for (var i = 0; i < _slices.length; i++)
          ClipRect(
            clipper: _Slice(_slices[i].$1, _slices[i].$2),
            child: Transform.translate(offset: Offset(_shifts[step][i], 0), child: child),
          ),
      ],
    );
  }
}

class _Slice extends CustomClipper<Rect> {
  const _Slice(this.top, this.bottom);

  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-16, size.height * top, size.width + 16, size.height * bottom);

  @override
  bool shouldReclip(_Slice old) => old.top != top || old.bottom != bottom;
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter(this.shader, {required this.time, required this.intensity, required this.still})
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
  bool shouldRepaint(_NebulaPainter old) => old.shader != shader || old.still != still;
}

/// Sixteen embers rising slowly and twinkling out, each on its own path.
class _EmbersPainter extends CustomPainter {
  _EmbersPainter({required this.time, required this.intensity, required this.exit})
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
  bool shouldRepaint(_EmbersPainter old) => false;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.grow, required this.time, required this.exit, required this.still})
    : super(repaint: Listenable.merge([grow, time, exit]));

  final Animation<double> grow;
  final ValueListenable<double> time;
  final Animation<double> exit;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final breath = still ? 0.0 : _breathAt(time.value);
    // From the splash's glow to the breathing one, then a flash on leaving.
    final radius = ui.lerpDouble(LoadingScreen.splashGlowRadius, 130, grow.value)! * (1 + 0.6 * exit.value);
    final alpha =
        ui.lerpDouble(LoadingScreen.splashGlowAlpha, 0.14 + 0.08 * breath, grow.value)! *
        (1 + exit.value) *
        (1 - exit.value);
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
  bool shouldRepaint(_GlowPainter old) => old.still != still;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.sweep,
    required this.pulse,
    required this.ticks,
    required this.time,
    required this.exit,
    required this.still,
  }) : super(repaint: Listenable.merge([sweep, pulse, ticks, time, exit]));

  final Animation<double> sweep;
  final Animation<double> pulse;
  final Animation<double> ticks;
  final ValueListenable<double> time;
  final Animation<double> exit;
  final bool still;

  static const double radius = 112;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final fade = 1 - exit.value;
    final s = sweep.value;
    if (fade <= 0 || s <= 0) return;
    final r = radius * (1 + 0.5 * exit.value);
    final turn = still ? 0.0 : time.value / 16 * 2 * math.pi; // one turn per 16 s
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
  bool shouldRepaint(_RingPainter old) => old.still != still;
}
