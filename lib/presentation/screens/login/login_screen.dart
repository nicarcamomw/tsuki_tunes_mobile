library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/legal_links.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/entities/auth_error.dart';
import '../../navigation/app_router.dart';
import '../../navigation/session_gate.dart';
import '../../state/app_providers.dart';
import '../../state/locale_provider.dart';
import '../../widgets/circular_reveal.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/haptics.dart';
import '../../widgets/motion.dart';
import '../../widgets/tsuki_sky.dart';
import '../loading_screen.dart';

part 'google_button.dart';

/// Where the sign-in stands, for the panel's line and the ring's pace.
enum _Status { idle, signingIn, granted, failed }

/// The login: the same night as the entrance, so the app opens as one
/// scene. The mask the loading screen left at the centre rises to the top
/// with its moon ring; the name appears with a flicker of signal; the ways
/// in arrive on a panel of liquid glass: Google's own button, the
/// observer's way, a line that says what's happening (offline, too many
/// tries with a countdown, an error with a way to try again) and the terms.
///
/// Signing in, the ring turns fast (it is the loader); signed in, the mask
/// blooms into the app; failed, the panel glitches once. With less motion
/// asked for, it all holds still. Light: one ticker, painters that repaint
/// without rebuilding, the shader warmed at startup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// How long the entrance takes (the mask rising, then the rest).
  static const Duration intro = Duration(milliseconds: 1400);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: LoginScreen.intro);
  late final AnimationController _shake = AnimationController(vsync: this, duration: AppMotion.slow);
  late final AnimationController _bloom = AnimationController(vsync: this, duration: AppMotion.flash);

  /// Where the mask stands, for the app to open out of it (RevealOrigin).
  Alignment _maskAt = Alignment.center;
  bool _entering = false;

  /// The session, while this screen holds it (signing someone in), kept to
  /// let go on the way out, when ref isn't usable any more.
  SessionGate? _held;

  void _hold() {
    final gate = ref.read(sessionGateProvider);
    _held = gate;
    gate.holdLogin(true);
  }

  void _release() {
    _held?.holdLogin(false);
    _held = null;
  }
  final ValueNotifier<double> _time = ValueNotifier(0);
  final ValueNotifier<double> _rotation = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  double _speed = _calm;
  ui.FragmentShader? _shader;
  Timer? _countdown;
  _Status _status = _Status.idle;
  String? _error;

  /// The ring's pace in radians a second: one turn in 16 s, or a loader's.
  static const double _calm = 2 * math.pi / 16;

  /// About how tall the glass panel and the footer under it stand.
  static const double _panelHeight = 245;
  static const double _busy = 2 * math.pi / 1.1;

  @override
  void initState() {
    super.initState();
    // On the first frame when loaded already (it is, after the entrance).
    _shader = tsukiNebulaShaderNow();
    if (_shader == null) {
      unawaited(tsukiNebulaProgram.then((program) {
        if (!mounted || program == null) return;
        setState(() => _shader = program.fragmentShader());
      }));
    }
    // In: the app starts opening out of the mask while the halo flashes,
    // not after (one movement, no wait in between).
    _bloom.addListener(() {
      if (_bloom.value >= 0.22) _enter();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _intro.value = 1;
      if (_ticker.isActive) _ticker.stop();
    } else {
      if (_intro.isDismissed) unawaited(_intro.forward());
      if (!_ticker.isActive) unawaited(_ticker.start());
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
    // The ring eases into its new pace instead of jumping to it.
    final target = _status == _Status.signingIn ? _busy : _calm;
    _speed += (target - _speed) * math.min(1, dt * 3);
    _rotation.value += _speed * dt;
  }

  @override
  void dispose() {
    // Never leave the router held on a login that's gone.
    final held = _held;
    if (held != null) scheduleMicrotask(() => held.holdLogin(false));
    _countdown?.cancel();
    _ticker.dispose();
    NebulaPainter.forget(_time);
    _time.dispose();
    _rotation.dispose();
    _intro.dispose();
    _shake.dispose();
    _bloom.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Animation<double> _part(double begin, double end, [Curve curve = AppMotion.enter]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  // ── Signing in ──

  Future<void> _signInWithGoogle() async {
    if (_status == _Status.signingIn || _status == _Status.granted) return;
    final auth = ref.read(authProvider);
    if (auth.isLoginThrottled) {
      _startCountdown();
      return;
    }
    Haptics.tap();
    setState(() {
      _status = _Status.signingIn;
      _error = null;
    });
    // Signed in, the router waits for this screen's way out.
    _hold();
    final ok = await auth.loginWithGoogle();
    if (!mounted) return;
    if (!ok) _release();
    if (ok) {
      Haptics.success();
      setState(() => _status = _Status.granted);
      if (reduceMotion(context)) {
        _enter();
      } else {
        unawaited(_bloom.forward());
      }
      return;
    }
    final strings = ref.read(localeProvider).strings;
    setState(() {
      _status = auth.wasCancelled ? _Status.idle : _Status.failed;
      _error = auth.wasCancelled
          ? null
          : auth.authError == AuthError.throttled
              ? null
              : strings.loginGoogleError;
    });
    if (auth.wasCancelled) return;
    Haptics.error();
    if (auth.authError == AuthError.throttled) _startCountdown();
    if (!reduceMotion(context)) unawaited(_shake.forward(from: 0));
  }

  /// Too many tries: a countdown on the panel until another is allowed.
  void _startCountdown() {
    _countdown?.cancel();
    setState(() {});
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (!ref.read(authProvider).isLoginThrottled) {
        t.cancel();
        _countdown = null;
      }
      setState(() {});
    });
  }

  /// Signed in: the account's library and playlists connect, and the router
  /// takes it from here (the tutorial for a new account, the main screen
  /// otherwise, or the page a link pointed to).
  void _enter() {
    if (!mounted || _entering) return;
    _entering = true;
    RevealOrigin.value = _maskAt;
    final auth = ref.read(authProvider);
    if (auth.uid != null && !auth.isGuest) {
      final uid = auth.uid!;
      unawaited(ref.read(libraryProvider).connectToFirestore(uid));
      final playlists = ref.read(playlistProvider);
      final guestUid = auth.takeGuestUidToMigrate();
      unawaited(playlists.connectToFirestore(uid).then((_) {
        if (guestUid != null) playlists.importGuestPlaylists(guestUid);
      }));
    }
    // Let go: the router takes it from here (the app, the tutorial, or the
    // first start getting ready, on the loading screen).
    _release();
    context.go(AppPaths.home);
  }

  Future<void> _enterAsObserver() async {
    Haptics.tap();
    _hold();
    await ref.read(authProvider).loginAsGuest();
    if (!mounted) return;
    // In the same way as signing in: the halo flashes, the app opens.
    if (reduceMotion(context)) {
      _enter();
    } else {
      unawaited(_bloom.forward());
    }
  }

  Future<void> _open(String url) async {
    Haptics.tap();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ── The screen ──

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final online = ref.watch(isOnlineProvider);
    final auth = ref.watch(authProvider);
    final still = reduceMotion(context);
    final throttle = auth.loginThrottleRemaining;
    final waiting = throttle > Duration.zero ? (throttle.inMilliseconds / 1000).ceil() : 0;

    // The mask rises from where the entrance left it once the reveal has
    // opened around it (routes.dart's revealPage), on Material's emphasized
    // curve; the halo builds itself meanwhile.
    final rise = _part(0.36, 0.9, Curves.easeInOutCubicEmphasized);
    final halo = _part(0.05, 1, Curves.linear);
    final title = _part(0.5, 0.85);
    final tagline = _part(0.6, 0.92);
    final panel = _part(0.6, 1);
    final bloom = CurvedAnimation(parent: _bloom, curve: AppMotion.exit);
    const still1 = AlwaysStoppedAnimation<double>(1);
    const zero = AlwaysStoppedAnimation<double>(0);

    // What the panel's line says, if anything.
    final (String? line, bool alarm) = !online
        ? (strings.loginOffline, false)
        : waiting > 0
            ? (strings.loginThrottledIn(waiting), true)
            : (_error, true);

    return Scaffold(
      backgroundColor: AppColors.splash,
      body: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          final top = MediaQuery.paddingOf(context).top;
          // The mask: from the centre (where the entrance left it) to the
          // middle of the room above the panel, with the name under it (the
          // halo's top 126 above the mask's centre, the line's end 222 below, under
          // the halo's moon phases).
          final from = h / 2;
          final panelTop = h - MediaQuery.paddingOf(context).bottom - _panelHeight;
          final to = math.max(top + 140, top + (panelTop - top - 348) / 2 + 126);
          _maskAt = Alignment(0, h <= 0 ? 0 : to / h * 2 - 1);
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // The night: nebula and embers, as in the entrance.
              if (_shader != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: NebulaPainter(_shader!, time: _time, intensity: still1, still: still)),
                  ),
                ),
              if (!still)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: EmbersPainter(time: _time, intensity: still1, exit: bloom)),
                  ),
                ),

              // The mask with its glow and ring, rising into place.
              AnimatedBuilder(
                animation: rise,
                child: _MaskAndRing(
                  time: _time,
                  rotation: _rotation,
                  assemble: halo,
                  bloom: bloom,
                  burst: _bloom,
                  still: still,
                ),
                builder: (context, child) => Positioned(
                  top: ui.lerpDouble(from, to, rise.value)! - 160,
                  left: 0,
                  right: 0,
                  height: 320,
                  child: child!,
                ),
              ),

              // The name and the line under it.
              Positioned(
                top: to + 152,
                left: AppSpacing.page,
                right: AppSpacing.page,
                child: FadeTransition(
                  opacity: ReverseAnimation(bloom),
                  child: Column(
                    children: [
                      _Title(appear: still ? still1 : title, locale: locale),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: still ? still1 : tagline,
                        child: ExcludeSemantics(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: strings.loginSubtitlePrefix),
                              TextSpan(text: strings.loginSubtitleGlitch, style: const TextStyle(color: AppColors.accentText)),
                            ]),
                            textAlign: TextAlign.center,
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // The ways in, on liquid glass.
              Positioned(
                left: AppSpacing.page,
                right: AppSpacing.page,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: FadeTransition(
                  opacity: still ? still1 : panel,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(still ? zero : panel),
                    child: FadeTransition(
                      opacity: ReverseAnimation(bloom),
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          // A short glitch: three jumps, fading out.
                          final t = _shake.value;
                          final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 6) * 10 * (1 - t);
                          return Transform.translate(offset: Offset(dx, 0), child: child);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FrostedGlass(
                              borderRadius: BorderRadius.circular(AppRadius.sheet),
                              // Perf: no backdrop blur. Behind it is only
                              // the dark nebula and a few embers, which a
                              // blur barely changes, yet it re-read the
                              // screen on every frame the night moves.
                              blur: 0,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _GoogleButton(
                                      label: _status == _Status.signingIn || _status == _Status.granted
                                          ? strings.loginSigningIn
                                          : _status == _Status.failed
                                              ? strings.loginRetry
                                              : strings.loginContinueGoogle,
                                      busy: _status == _Status.signingIn || _status == _Status.granted,
                                      onPressed: online && waiting == 0 ? _signInWithGoogle : null,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _status == _Status.signingIn || _status == _Status.granted
                                            ? null
                                            : _enterAsObserver,
                                        icon: const Icon(Icons.visibility_outlined, size: 18),
                                        label: Text(strings.loginObserver),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(50),
                                          foregroundColor: AppColors.textPrimary,
                                          shape: const StadiumBorder(),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                                        ),
                                      ),
                                    ),
                                    // What's happening, said in place.
                                    AnimatedSize(
                                      duration: AppMotion.normal,
                                      curve: AppMotion.move,
                                      child: line == null
                                          ? const SizedBox(width: double.infinity, height: 8)
                                          : Padding(
                                              padding: const EdgeInsets.only(top: 12),
                                              child: Semantics(
                                                liveRegion: true,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      alarm ? Icons.error_outline_rounded : Icons.wifi_off_rounded,
                                                      size: 16,
                                                      color: AppColors.textBright,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        line,
                                                        style: locale.getTextStyle(
                                                          fontSize: AppFontSize.body,
                                                          color: AppColors.textBright,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 4),
                                    _Terms(locale: locale, onOpen: _open),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ExcludeSemantics(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(double.infinity, 16),
                                  painter: _CompanyPainter(
                                    time: _time,
                                    style: locale.getTextStyle(
                                      fontSize: AppFontSize.micro,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2.2,
                                    ),
                                    still: still,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The entrance's mask, its glow and its moon ring (complete, turning at
/// the pace the screen sets), blooming on the way in.
class _MaskAndRing extends StatelessWidget {
  const _MaskAndRing({
    required this.time,
    required this.rotation,
    required this.assemble,
    required this.bloom,
    required this.burst,
    required this.still,
  });

  final ValueNotifier<double> time;
  final ValueNotifier<double> rotation;

  /// The halo building itself as the screen comes in (0 to 1).
  final Animation<double> assemble;
  final Animation<double> bloom;

  /// Letting you in, linear (the halo's burst of waves).
  final Animation<double> burst;
  final bool still;

  static const _full = AlwaysStoppedAnimation<double>(1);

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        // The burst's waves run well past the halo.
        clipBehavior: Clip.none,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(300),
              painter: MoonGlowPainter(grow: _full, time: time, exit: bloom, still: still),
            ),
          ),
          // The lunar dial (HaloRingPainter): it carries on the entrance's
          // ring and builds itself as the screen comes in.
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(320),
              painter: HaloRingPainter(
                rotation: rotation,
                assemble: still ? _full : assemble,
                exit: bloom,
                burst: burst,
                still: still,
              ),
            ),
          ),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([time, bloom]),
              child: const ExcludeSemantics(
                child: Image(
                  image: AssetImage(LoadingScreen.maskAsset),
                  width: LoadingScreen.maskWidth,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
              builder: (context, mask) {
                final breath = still ? 0.0 : breathAt(time.value);
                return Opacity(
                  opacity: 1 - bloom.value,
                  child: Transform.scale(scale: (1 + 0.025 * breath) * (1 + 0.12 * bloom.value), child: mask),
                );
              },
            ),
          ),
        ],
      );
}

/// TSUKI TUNES, appearing with one flicker of signal: red and cyan ghosts
/// that settle into the name.
class _Title extends StatelessWidget {
  const _Title({required this.appear, required this.locale});

  final Animation<double> appear;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color tunes, [Color? all]) => locale.getTextStyle(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.w900,
          color: all ?? AppColors.textBright,
          letterSpacing: 6,
        );
    Widget name({Color? all}) => Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'TSUKI '),
            TextSpan(text: 'TUNES', style: TextStyle(color: all ?? AppColors.accentText)),
          ]),
          style: style(AppColors.accentText, all),
        );
    return Semantics(
      header: true,
      label: 'Tsuki Tunes',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: appear,
          builder: (context, _) {
            final t = appear.value;
            // The ghosts flicker over the first half of the appearance.
            final glitch = t > 0 && t < 0.5 ? (1 - t / 0.5) : 0.0;
            final dx = glitch * (t * 40 % 2 < 1 ? 4.0 : -3.0);
            return Opacity(
              opacity: t,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (glitch > 0) ...[
                    Transform.translate(offset: Offset(dx, 0), child: name(all: AppColors.accent.withValues(alpha: 0.6 * glitch))),
                    Transform.translate(offset: Offset(-dx, 0), child: name(all: AppColors.neonCyan.withValues(alpha: 0.45 * glitch))),
                  ],
                  name(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "By continuing you accept the Terms and the Privacy Policy", the two
/// opening their pages.
class _Terms extends StatelessWidget {
  const _Terms({required this.locale, required this.onOpen});

  final LocaleProvider locale;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final small = locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted);
    final link = locale.getTextStyle(
      fontSize: AppFontSize.caption,
      fontWeight: FontWeight.w700,
      color: AppColors.textBright,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textMuted,
    );
    Widget button(String text, String url) => TextButton(
          onPressed: () => onOpen(url),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.textBright,
          ),
          child: Text(text, style: link),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(strings.loginTermsLead, style: small),
        button(strings.loginTerms, termsOfServiceUrl),
        Text(strings.loginAnd, style: small),
        button(strings.loginPrivacy, privacyPolicyUrl),
      ],
    );
  }
}

/// METAWORKS COMPANY between a cyan and a red point, its letters running
/// from cyan through blue into the app's red, the colours drifting slowly
/// side to side (the login's signature since its first version).
///
/// Light: the gradient is the text's own paint (no layer, no ShaderMask)
/// and the points' glow a gradient (no blur); one small line laid out per
/// frame, on a layer of its own.
class _CompanyPainter extends CustomPainter {
  _CompanyPainter({required this.time, required this.style, required this.still}) : super(repaint: still ? null : time);

  final ValueListenable<double> time;
  final TextStyle style;
  final bool still;

  static const String _name = 'METAWORKS COMPANY';
  static const _colors = [AppColors.neonCyan, AppColors.skyBlue, AppColors.crimsonNeon, AppColors.accent];
  static const _stops = [0.0, 0.35, 0.7, 1.0];

  // The line's size, measured once (the painter lives across frames).
  Size? _measured;

  @override
  void paint(Canvas canvas, Size size) {
    final measured = _measured ??= () {
      final m = TextPainter(text: TextSpan(text: _name, style: style), textDirection: TextDirection.ltr)..layout();
      final s = m.size;
      m.dispose();
      return s;
    }();
    final w = measured.width;
    final h = measured.height;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    // The colours drift a third of the way each side, slowly (about 10 s).
    final shift = still ? 0.0 : math.sin(time.value * 0.6) * 0.35;
    final from = Offset(left + w * (-0.05 + shift / 2), 0);
    final to = Offset(left + w * (1.05 + shift / 2), 0);
    final text = TextPainter(
      text: TextSpan(
        text: _name,
        style: style.copyWith(foreground: Paint()..shader = ui.Gradient.linear(from, to, _colors, _stops)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(left, top));
    text.dispose();
    final cy = size.height / 2;
    _dot(canvas, Offset(left - 12, cy), AppColors.neonCyan);
    _dot(canvas, Offset(left + w + 10, cy), AppColors.accent);
  }

  static void _dot(Canvas canvas, Offset c, Color color) {
    canvas
      ..drawCircle(c, 7, Paint()..shader = ui.Gradient.radial(c, 7, [color.withValues(alpha: 0.6), color.withValues(alpha: 0)]))
      ..drawCircle(c, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CompanyPainter old) => old.style != style || old.still != still;
}

