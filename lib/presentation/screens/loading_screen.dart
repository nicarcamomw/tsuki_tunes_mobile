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
import '../state/locale_provider.dart';
import '../widgets/motion.dart';
import '../widgets/render_warm_up.dart';
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
  // The caret's blink (on/off twice a second for a moment after typing):
  // its own notifier, so the name rebuilds when it blinks, not every frame.
  final ValueNotifier<bool> _blink = ValueNotifier(true);
  late final Ticker _ticker = createTicker((elapsed) {
    _time.value = elapsed.inMicroseconds / 1e6;
    _rotation.value = _time.value / 16 * 2 * math.pi;
    _blink.value = (_time.value * 2).floor().isEven;
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
    _shader = tsukiNebulaShaderNow();
    if (_shader == null) {
      unawaited(
        LoadingScreen.nebula.then((program) {
          if (!mounted || program == null) return;
          setState(() => _shader = program.fragmentShader());
        }),
      );
    }
    // The GPU's head start (RenderWarmUp), on this screen's first frame:
    // Android's splash carried on, nothing moving yet to stutter. What the
    // login and the app's portal draw is then ready when they come.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(RenderWarmUp.run()));
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
      if (!_ticker.isActive && !_leaving) unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _patience?.cancel();
    _ticker.dispose();
    NebulaPainter.forget(_time);
    _time.dispose();
    _rotation.dispose();
    _blink.dispose();
    _intro.dispose();
    _exit.dispose();
    _shader?.dispose();
    super.dispose();
  }

  bool _warmed = false;

  /// On its way out: its night holds still.
  bool _leaving = false;

  /// A first start getting ready: the effects the app draws (gradients,
  /// blurs, clips, layers, the halo) drawn once off screen, so the GPU
  /// builds what it needs for them here, while this screen waits, and not
  /// on the first frames of the app.
  void _warmUp() {
    if (_warmed) return;
    _warmed = true;
    unawaited(RenderWarmUp.run());
  }

  Animation<double> _part(double begin, double end, [Curve curve = Curves.linear]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    // Ready: the name leaves and the next screen opens out of the mask.
    // A first start getting ready stays here, saying what it's doing.
    final status = ref.watch(sessionGateProvider.select((g) => g.status));
    final preparing = status == SessionStatus.preparing;
    if (preparing) _warmUp();
    ref.listen<SessionStatus>(sessionGateProvider.select((g) => g.status), (_, status) {
      final leaving = status != SessionStatus.loading && status != SessionStatus.preparing;
      if (leaving && !reduceMotion(context)) unawaited(_exit.forward());
      // Perf: the next screen opens over this one; its night stops here
      // (the sky, ring and embers hold their last frame) so only one
      // screen animates under the portal.
      if (leaving) {
        _leaving = true;
        if (_ticker.isActive) _ticker.stop();
      }
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
    final rule = _part(0.7, 1, AppMotion.enter);
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
              // Depth: the corners sink into the night. Static, it fades
              // in with the sky (the splash's first frame has none).
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: sky,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.05,
                          colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.5)],
                          stops: [0.55, 1],
                        ),
                      ),
                    ),
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
                    // It stays as it is on the way out: the next screen
                    // opens out of it (CircularReveal), and the login's
                    // own mask starts right here.
                    final scale = 1 + 0.025 * breath;
                    final scanning = !still && _intro.value > 0.15 && _intro.value < 0.65;
                    final glitch = !still && _intro.value > 0.55 && _intro.value < 0.72 ? _intro.value : null;
                    Widget out = mask!;
                    if (scanning) out = _Scan(progress: scan.value, child: out);
                    if (glitch != null) out = _Glitch(seed: glitch, child: out);
                    return Transform.scale(scale: scale, child: out);
                  },
                ),
              ),
              // The name, typing itself under the ring with a caret, as
              // the login will show it (TSUKI white, TUNES red), and a line
              // of light drawing out beneath it.
              Positioned(
                top: MediaQuery.sizeOf(context).height / 2 + 146,
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([type, rule, _exit, _blink]),
                    builder: (context, _) => Opacity(
                      opacity: 1 - exit.value,
                      child: _TypedName(
                        locale: locale,
                        typed: type.value,
                        rule: rule.value,
                        // The caret blinks while it types and a moment after.
                        // Not before typing starts: the first frames are
                        // Android's splash, carried on as it was.
                        caret: still || _intro.value < 0.3
                            ? 0
                            : type.value < 1
                                ? 1
                                : (_time.value < 3 && _blink.value ? 1 : 0),
                      ),
                    ),
                  ),
                ),
              ),
              // At the bottom, only if waking takes a moment: a thin
              // light running along a hairline, and the words.
              Positioned(
                left: 32,
                right: 32,
                bottom: MediaQuery.paddingOf(context).bottom + 56,
                child: AnimatedOpacity(
                  opacity: _slow || preparing ? 1 : 0,
                  duration: AppMotion.slow,
                  curve: AppMotion.enter,
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_slow || preparing)
                          RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(72, 2),
                              painter: _WakingLinePainter(time: _time, still: still),
                            ),
                          ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<PrepStep?>(
                          valueListenable: ref.read(sessionGateProvider).prepStep,
                          builder: (context, step, _) => AnimatedSwitcher(
                            duration: AppMotion.normal,
                            child: Text(
                          switch (step) {
                            PrepStep.library => strings.loadingPrepLibrary,
                            PrepStep.settling => strings.loadingPrepSettling,
                            null => strings.loadingWaking,
                          },
                          key: ValueKey(step),
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
                      ],
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

/// TSUKI TUNES as the login shows it, [typed] (0–1) of it written, the rest
/// held in place unseen (so the letters never shift), a [caret] after the
/// last letter, and a short line of light [rule] (0–1) drawn out under it.
class _TypedName extends StatelessWidget {
  const _TypedName({required this.locale, required this.typed, required this.rule, required this.caret});

  final LocaleProvider locale;
  final double typed;
  final double rule;
  final double caret;

  static const _name = 'TSUKI TUNES';
  static const _split = 6; // "TSUKI "

  @override
  Widget build(BuildContext context) {
    final shown = (_name.length * typed).round();
    final style = locale.getTextStyle(
      fontSize: AppFontSize.titleLg,
      fontWeight: FontWeight.w900,
      color: AppColors.textBright,
      letterSpacing: 6,
    );
    const hidden = TextStyle(color: Colors.transparent);
    final white = _name.substring(0, math.min(shown, _split));
    final red = shown > _split ? _name.substring(_split, shown) : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: white),
            TextSpan(text: red, style: const TextStyle(color: AppColors.accentText)),
            // The caret takes no room: it sits over the next letter's
            // place, which is there already, unseen.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: 0,
                height: AppFontSize.titleLg * 1.1,
                child: OverflowBox(
                  maxWidth: 4,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2.5,
                    height: AppFontSize.titleLg * 1.1,
                    color: AppColors.accent.withValues(alpha: caret),
                  ),
                ),
              ),
            ),
            TextSpan(text: _name.substring(shown), style: hidden),
          ]),
          style: style,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          width: 72 * rule,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent,
              AppColors.accent.withValues(alpha: 0),
            ]),
          ),
        ),
      ],
    );
  }
}

/// A hairline with a short light running along it, over and over, while
/// waking takes a moment. Still: the hairline, lit in the middle.
class _WakingLinePainter extends CustomPainter {
  _WakingLinePainter({required this.time, required this.still}) : super(repaint: still ? null : time);

  final ValueListenable<double> time;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.25)
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), track);
    final t = still ? 0.5 : (time.value / 1.4) % 1;
    final head = Curves.easeInOut.transform(t);
    final w = size.width * 0.35;
    final x = -w + (size.width + w) * head;
    final light = Paint()
      ..shader = ui.Gradient.linear(Offset(x, y), Offset(x + w, y), [
        AppColors.accent.withValues(alpha: 0),
        AppColors.accent,
        AppColors.accent.withValues(alpha: 0),
      ], const [0, 0.5, 1])
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(Offset(x, y), Offset(x + w, y), light);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WakingLinePainter old) => old.still != still;
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
