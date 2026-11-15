import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/session_gate.dart';
import '../state/app_providers.dart';
import '../widgets/motion.dart';
import '../widgets/tsuki_sky.dart';

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
  static Future<ui.FragmentProgram?> get nebula => tsukiNebulaProgram;

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

class _LoadingScreenState extends ConsumerState<LoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: LoadingScreen.intro);
  late final AnimationController _exit = AnimationController(vsync: this, duration: AppMotion.normal);
  // Seconds since the screen opened: the nebula, the breath, the ring's turn
  // and the embers all read it. It never wraps, so nothing ever jumps.
  final ValueNotifier<double> _time = ValueNotifier(0);
  // The ring's turn: one every 16 s.
  final ValueNotifier<double> _rotation = ValueNotifier(0);
  late final Ticker _ticker = createTicker((elapsed) {
    _time.value = elapsed.inMicroseconds / 1e6;
    _rotation.value = _time.value / 16 * 2 * math.pi;
  });
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
    _rotation.dispose();
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
                      painter: NebulaPainter(_shader!, time: _time, intensity: sky, still: still),
                    ),
                  ),
                ),
              // A few embers rising slowly through it.
              if (!still)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: EmbersPainter(time: _time, intensity: sky, exit: exit),
                    ),
                  ),
                ),
              // The red glow behind the mask, breathing, and its shadow.
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(300),
                  painter: MoonGlowPainter(grow: glowIn, time: _time, exit: exit, still: still),
                ),
              ),
              // The moon ring, drawing itself, then turning slowly.
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size.square(320),
                  painter: MoonRingPainter(
                    sweep: ring,
                    pulse: pulse,
                    ticks: ticks,
                    rotation: _rotation,
                    exit: exit,
                    still: still,
                  ),
                ),
              ),
              // The mask: breath, scan and glitch.
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _time, _exit]),
                  child: mask,
                  builder: (context, mask) {
                    final breath = still ? 0.0 : breathAt(_time.value);
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
