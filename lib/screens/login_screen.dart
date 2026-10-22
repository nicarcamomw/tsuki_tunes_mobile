import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_strings.dart';
import '../services/storage_service.dart';
import '../widgets/cyber_orb.dart';
import '../widgets/cyber_glitch_text.dart';
import '../widgets/spectrum_wave_visualizer.dart';
import 'onboarding_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _shockwaveController;
  final GlobalKey _orbKey = GlobalKey();
  Offset? _cachedOrbCenter;
  final ValueNotifier<double> _timeNotifier = ValueNotifier<double>(0.0);
  bool _isLoading = false;
  bool _loginSuccess = false;
  bool? _cachedNeedsOnboarding;

  // High-performance deterministic particle seeds for cyber dust / embers
  final List<_CyberParticle> _particles = _generateParticles();

  static List<_CyberParticle> _generateParticles() {
    final rng = Random(77);
    return List.generate(28, (i) {
      return _CyberParticle(
        baseX: rng.nextDouble(),
        baseY: rng.nextDouble(),
        size: 1.2 + rng.nextDouble() * 2.2,
        speed: 0.08 + rng.nextDouble() * 0.14,
        maxOpacity: 0.35 + rng.nextDouble() * 0.5,
        phase: rng.nextDouble() * 2 * pi,
        isCrimson: rng.nextBool(),
      );
    });
  }

  @override
  void initState() {
    super.initState();

    // Shockwave animation on successful Google login (~950ms detonation)
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _shockwaveController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.uid != null && !auth.isGuest) {
          context.read<LibraryProvider>().connectToFirestore(auth.uid!);
        }
        _navigateAfterLogin();
      }
    });

    // Continuous monotonic ticker driving 120 FPS high-precision time without root rebuilds
    _ticker = createTicker((elapsed) {
      if (mounted) {
        _timeNotifier.value = elapsed.inMicroseconds / 1000000.0;
      }
    });
    _ticker.start();
  }

  Future<void> _navigateAfterLogin() async {
    final needsOnboarding = _cachedNeedsOnboarding ??
        !await StorageService().hasCompletedOnboarding();
    if (!mounted) return;

    final Widget destination = needsOnboarding
        ? const OnboardingScreen()
        : const MainNavigationScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _handleGuestExplore() async {
    final auth = context.read<AuthProvider>();
    await auth.loginAsGuest();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timeNotifier.dispose();
    _shockwaveController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final onboardingFuture = StorageService().hasCompletedOnboarding();
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();
    _cachedNeedsOnboarding = !await onboardingFuture;
    if (mounted) {
      if (success) {
        _cachedOrbCenter = _getOrbCenter(MediaQuery.sizeOf(context));
        setState(() {
          _isLoading = false;
          _loginSuccess = true;
        });
        _shockwaveController.forward();
      } else {
        setState(() => _isLoading = false);
        if (!auth.wasCancelled) {
          final locale = context.read<LocaleProvider>();
          final strings = locale.strings;
          final msg = strings.loginGoogleError;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg,
                      style: locale.getTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.bgCard,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.error, width: 1.2),
              ),
            ),
          );
        }
      }
    }
  }

  static const _countryKanjiMap = <String, String>{
    'CL': '智利', 'US': '米国', 'JP': '日本', 'MX': '墨西哥',
    'AR': '亜国', 'BR': '伯国', 'ES': '西班牙', 'CO': '哥倫比亜',
    'PE': '秘露', 'VE': '委内瑞拉', 'EC': '厄瓜多爾', 'BO': '玻利維亜',
    'PY': '巴拉圭', 'UY': '烏拉圭', 'CR': '哥斯大黎加',
    'GB': '英国', 'FR': '仏国', 'DE': '独国', 'IT': '伊国',
    'CA': '加国', 'AU': '豪州', 'KR': '韓国', 'CN': '中国',
    'IN': '印度', 'RU': '露国', 'PT': '葡国',
  };

  String _getCountryKanji(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final code = locale.countryCode ?? '';
    return _countryKanjiMap[code] ?? '世界';
  }

  Offset _getOrbCenter(Size fallbackSize) {
    final renderBox = _orbKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return renderBox.localToGlobal(
        Offset(renderBox.size.width / 2, renderBox.size.height / 2),
      );
    }
    return Offset(fallbackSize.width * 0.5, fallbackSize.height * 0.32);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // 1. Cyber Grid Matrix Background (Static, zero CPU overhead)
          Positioned.fill(
            child: CustomPaint(painter: const _CyberGridPainter()),
          ),

          // 2. Continuous Drifting Cyber Audio Particles (Isolated RepaintBoundary)
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _timeNotifier,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _CyberParticlesPainter(
                      particles: _particles,
                      time: t,
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Ambient Breathing Plasma Glow Behind Center Orb (Isolated RepaintBoundary)
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.12,
            width: size.width * 0.76,
            height: size.width * 0.76,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _timeNotifier,
                  builder: (context, t, _) {
                    return CustomPaint(
                      painter: _PlasmaGlowPainter(time: t),
                    );
                  },
                ),
              ),
            ),
          ),

          // 4. Ambient Horizontal Spectrum Waves (Behind UI, lower screen)
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.10,
            height: size.height * 0.22,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _timeNotifier,
                  builder: (context, t, _) {
                    return CustomPaint(
                      painter: SpectrumWavePainter(time: t, intensity: 0.5),
                    );
                  },
                ),
              ),
            ),
          ),

          // 6. Main Cyberpunk Foreground Interface
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  // Top Cyber Status Telemetry HUD Bar
                  _buildHudTopBar(locale, strings),

                  const Spacer(flex: 3),

                  // Center 3D Plasma Holographic Orb with Radial Audio Equalizer
                  _buildHeroEmblem(),

                  const SizedBox(height: 16),

                  // Cyberpunk Neon Typography
                  _buildBrandingHeader(locale, strings),

                  const Spacer(flex: 3),

                  // Cyberpunk Neural Link Google Button (120 FPS High-Performance Component)
                  _CyberGoogleButton(
                    onPressed: _handleGoogleLogin,
                    isLoading: _isLoading,
                    loginSuccess: _loginSuccess,
                    timeListenable: _timeNotifier,
                    locale: locale,
                    strings: strings,
                  ),

                  const SizedBox(height: 14),

                  // Guest Explore Button (secondary, visible)
                  Semantics(
                    button: true,
                    label: strings.a11yContinueAsGuest,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleGuestExplore,
                      borderRadius: BorderRadius.circular(24),
                      splashColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          strings.loginGuestExplore,
                          style: locale.getTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),

                  const Spacer(flex: 2),

                  // Company Brand Footer (Isolated RepaintBoundary)
                  RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _timeNotifier,
                      builder: (context, t, _) => _buildCompanyFooter(t),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 7. Successful Auth Shockwave Blast (Centered at Hero Orb, Isolated Layer)
          if (_loginSuccess)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _shockwaveController,
                    builder: (context, child) {
                      final center = _cachedOrbCenter ?? _getOrbCenter(size);
                      return CustomPaint(
                        painter: _ShockwavePainter(
                          progress: _shockwaveController.value,
                          epicenter: center,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Top Navigation & Quick Catalog Access Bar (Option 3) ---
  Widget _buildHudTopBar(LocaleProvider locale, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Identity with Glowing Cyber Dot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _timeNotifier,
                  builder: (context, t, _) {
                    return CustomPaint(
                      size: const Size(12, 12),
                      painter: _PulseDotPainter(time: t),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TSUKI TUNES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBright,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  _getCountryKanji(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  // --- Company Brand Footer: Fixed Dots & Shimmering Words ---
  Widget _buildCompanyFooter(double t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _FooterDot(color: AppColors.neonCyan),
        const SizedBox(width: 8),

        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shift = sin(t * 0.6) * 0.35;
            return LinearGradient(
              begin: Alignment(-1.1 + shift, 0.0),
              end: Alignment(1.1 + shift, 0.0),
              colors: const [
                AppColors.neonCyan,
                Color(0xFF0099FF),
                Color(0xFFFF2B40),
                AppColors.accent,
              ],
              stops: const [0.0, 0.35, 0.70, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            'METAWORKS COMPANY',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.2,
            ),
          ),
        ),
        const SizedBox(width: 8),

        const _FooterDot(color: AppColors.accent),
      ],
    );
  }

  // --- Hero Centerpiece with 360-Degree Radial Equalizer Waveform ---
  Widget _buildHeroEmblem() {
    return SizedBox(
      key: _orbKey,
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Dynamic 360-Degree Harmonic Equalizer Bars (Around Central Orb)
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _timeNotifier,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _RadialSoundWavePainter(time: t),
                  );
                },
              ),
            ),
          ),

          // 2. Central Plasma CyberOrb with Tengu/Oni Core (Clean 3D Sphere)
          CyberOrb(
            size: 138,
            showOuterRings: false,
            centerChild: Image.asset(
              'assets/images/tengu.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              color: Colors.white.withValues(alpha: 0.95),
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }

  // --- Cyberpunk Neon Typography ---
  Widget _buildBrandingHeader(LocaleProvider locale, AppStrings strings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Title — TSUKI white, TUNES crimson
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'TSUKI',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.5,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TUNES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.5,
                color: AppColors.accent,
                shadows: [
                  Shadow(
                    color: AppColors.accent.withValues(alpha: 0.65),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 1.5,
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              strings.loginSubtitlePrefix,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 2.2,
              ),
            ),
            CyberGlitchText(text: strings.loginSubtitleGlitch),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 1.5,
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dedicated High-Performance Cyberpunk Neural Link Google Button
/// Encapsulates:
/// - 120 FPS angled laser shimmer sweep with instantaneous subpixel motion
/// - Zero-allocation direct canvas mask rendering via preloaded ui.Image
/// - Explosive concentric shockwave ripple on tap with tactile haptic feedback
class _CyberGoogleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool loginSuccess;
  final ValueListenable<double> timeListenable;
  final LocaleProvider locale;
  final AppStrings strings;

  const _CyberGoogleButton({
    required this.onPressed,
    required this.isLoading,
    required this.loginSuccess,
    required this.timeListenable,
    required this.locale,
    required this.strings,
  });

  @override
  State<_CyberGoogleButton> createState() => _CyberGoogleButtonState();
}

class _CyberGoogleButtonState extends State<_CyberGoogleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;
  Offset _tapEpicenter = Offset.zero;

  ui.Image? _oniImg;
  ui.Image? _hannyaImg;
  ui.Image? _tenguImg;
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadMaskImages();
  }

  Future<void> _loadMaskImages() async {
    try {
      final results = await Future.wait([
        _loadAsset('assets/images/oni.png'),
        _loadAsset('assets/images/hannya.png'),
        _loadAsset('assets/images/tengu.png'),
      ]);
      if (mounted) {
        setState(() {
          _oniImg = results[0];
          _hannyaImg = results[1];
          _tenguImg = results[2];
          _imagesLoaded = true;
        });
      }
    } catch (_) {
      // Graceful fallback: button operates seamlessly even if assets are delayed
    }
  }

  Future<ui.Image> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 40,
      targetHeight: 40,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _oniImg?.dispose();
    _hannyaImg?.dispose();
    _tenguImg?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isLoading || widget.loginSuccess) return;
    HapticFeedback.lightImpact();
    _tapEpicenter = details.localPosition;
    _rippleController.forward(from: 0.0);
  }

  Future<void> _handleTap() async {
    if (widget.isLoading || widget.loginSuccess) return;
    // Micro-delay ensures the 120 FPS shockwave detonation leads the user interaction before async thread dispatching
    await Future.delayed(const Duration(milliseconds: 70));
    if (mounted) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 1. Crimson gradient background
            Container(
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2A0A0D),
                    Color(0xFF1A0608),
                    Color(0xFF250A0E),
                  ],
                ),
              ),
            ),

            // 2. Falling Japanese Masks (Direct canvas draw, 0 GC, 120 FPS)
            if (_imagesLoaded)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.timeListenable,
                      builder: (context, t, _) {
                        return CustomPaint(
                          painter: _ButtonMaskPainter(
                            time: t,
                            oni: _oniImg,
                            hannya: _hannyaImg,
                            tengu: _tenguImg,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // 4. Concentric Shockwave Ripple on Tap (Snappy 440ms, full-button expansion)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) {
                      if (_rippleController.value == 0.0 ||
                          _rippleController.value == 1.0) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        painter: _ButtonShockwaveRipplePainter(
                          progress: _rippleController.value,
                          center: _tapEpicenter,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 5. Button Hit-Target & Interactive Typography
            Semantics(
              button: true,
              label: widget.strings.a11yLoginWithGoogle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTap: _handleTap,
              child: SizedBox(
                height: 54,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: widget.loginSuccess
                      ? Row(
                          key: const ValueKey('granted'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.strings.loginGranted,
                              style: widget.locale.getTextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        )
                      : widget.isLoading
                          ? Row(
                              key: const ValueKey('loading'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.strings.loginLoading,
                                  style: widget.locale.getTextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('idle'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const CustomPaint(
                                    size: Size(16, 16),
                                    painter: _GoogleLogoPainter(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  widget.strings.loginGoogle,
                                  style: widget.locale.getTextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
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

// ---------------------------------------------------------
// CUSTOM PAINTERS & CONTINUOUS MATHEMATICAL SHADERS
// (100% SEAMLESS, NO JUMP CUTS, INFINITE C-INFINITY MOTIONS)
// ---------------------------------------------------------

/// Ultra-Premium 360-Degree Studio Acoustic Wave Visualizer
/// Features dynamic bass-breathing orbit, 48 fluid stereo-interference equalizer bars,
/// ambient acoustic ribbon underlay, mirrored depth echoes, and 100% pure crimson neon glow.
class _RadialSoundWavePainter extends CustomPainter {
  final double time;

  const _RadialSoundWavePainter({required this.time});

  static final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  static final Paint _innerGlowRing = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.09)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  static final Paint _ribbonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..color = AppColors.accent.withValues(alpha: 0.18);

  static final Paint _reflectionPaint = Paint()..strokeCap = StrokeCap.round;

  static final Paint _glowPaint = Paint()
    ..strokeCap = StrokeCap.round;

  static final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const barCount = 48;

    final bassPulse = pow(max(0.0, sin(time * 3.2)), 4.0) * 2.2;
    final baseRadius = 76.0 + bassPulse;

    _trackPaint.color = AppColors.accent.withValues(alpha: 0.22 + (bassPulse * 0.08));
    canvas.drawCircle(center, baseRadius, _trackPaint);
    canvas.drawCircle(center, baseRadius - 2.5, _innerGlowRing);

    final ribbonPath = Path();
    const ribbonSteps = 120;
    for (int s = 0; s <= ribbonSteps; s++) {
      final tStep = (s / ribbonSteps) * 2 * pi;
      final wA = sin((time * 3.2) + (tStep * 3.0));
      final wB = cos((-time * 4.2) + (tStep * 2.0));
      final rDelta = (wA * 0.55 + wB * 0.45) * 6.5;
      final rRibbon = baseRadius + 10.0 + rDelta;

      final rx = center.dx + cos(tStep) * rRibbon;
      final ry = center.dy + sin(tStep) * rRibbon;

      if (s == 0) {
        ribbonPath.moveTo(rx, ry);
      } else {
        ribbonPath.lineTo(rx, ry);
      }
    }
    ribbonPath.close();
    canvas.drawPath(ribbonPath, _ribbonPaint);

    for (int i = 0; i < barCount; i++) {
      final theta = (i / barCount) * 2 * pi;
      final isPrimary = (i % 2 == 0);

      final wave1 = sin((time * 3.6) + (theta * 3.0));
      final wave2 = cos((-time * 4.6) + (theta * 2.0));
      final wave3 = sin((time * 1.8) - (theta * 4.0));
      final wave4 = cos((time * 6.0) + (theta * 1.0)) * 0.15;

      final raw = ((wave1 * 0.40 + wave2 * 0.36 + wave3 * 0.24 + wave4) + 1.0) / 2.0;

      final maxLen = isPrimary ? 22.0 : 15.0;
      final minLen = isPrimary ? 4.5 : 3.0;
      final barLen = minLen + (raw.clamp(0.0, 1.0) * (maxLen - minLen));

      final cosT = cos(theta);
      final sinT = sin(theta);

      final pStart = Offset(
        center.dx + cosT * baseRadius,
        center.dy + sinT * baseRadius,
      );
      final pEnd = Offset(
        center.dx + cosT * (baseRadius + barLen),
        center.dy + sinT * (baseRadius + barLen),
      );

      final pInnerEnd = Offset(
        center.dx + cosT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
        center.dy + sinT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
      );

      final barThickness = isPrimary ? 3.0 : 2.0;

      _reflectionPaint
        ..color = AppColors.accent.withValues(alpha: 0.16)
        ..strokeWidth = barThickness * 0.8;
      canvas.drawLine(pStart, pInnerEnd, _reflectionPaint);

      _glowPaint
        ..color = AppColors.accent.withValues(alpha: isPrimary ? 0.35 : 0.20)
        ..strokeWidth = barThickness + 4.0;
      canvas.drawLine(pStart, pEnd, _glowPaint);

      _corePaint
        ..strokeWidth = barThickness
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF55000A),
            AppColors.accent,
            Color(0xFFFF2B40),
            Color(0xFFFF485B),
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ).createShader(Rect.fromPoints(pStart, pEnd));
      canvas.drawLine(pStart, pEnd, _corePaint);

      if (raw > 0.65 && isPrimary) {
        final highlightFraction = ((raw - 0.65) / 0.35).clamp(0.0, 1.0);
        final pMid = Offset.lerp(pStart, pEnd, 0.55)!;
        _highlightPaint.color = const Color(0xFFFF6677).withValues(alpha: 0.70 * highlightFraction);
        canvas.drawLine(pMid, pEnd, _highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialSoundWavePainter oldDelegate) =>
      oldDelegate.time != time;
}

/// Ambient plasma glow rendered directly on canvas (no BoxDecoration allocation per frame)
class _PlasmaGlowPainter extends CustomPainter {
  final double time;
  const _PlasmaGlowPainter({required this.time});

  static final Paint _glowPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final breath = sin(time * 1.8);

    _glowPaint.shader = RadialGradient(
      radius: 0.52 + 0.12 * breath,
      colors: [
        AppColors.accent.withValues(alpha: 0.26 + 0.08 * breath),
        AppColors.accent.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, _glowPaint);
  }

  @override
  bool shouldRepaint(covariant _PlasmaGlowPainter old) => old.time != time;
}

/// Cyber Grid Painter with Tech Crosshairs
class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter();

  static final Paint _linePaint = Paint()
    ..color = const Color(0x06FFFFFF)
    ..strokeWidth = 0.5;

  static final Paint _crossPaint = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.13)
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 44.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);
    }

    const crossSize = 3.0;
    for (double x = spacing; x < size.width; x += spacing * 2) {
      for (double y = spacing; y < size.height; y += spacing * 2) {
        canvas.drawLine(Offset(x - crossSize, y), Offset(x + crossSize, y), _crossPaint);
        canvas.drawLine(Offset(x, y - crossSize), Offset(x, y + crossSize), _crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) => false;
}

/// Particle Data Model
class _CyberParticle {
  final double baseX;
  final double baseY;
  final double size;
  final double speed;
  final double maxOpacity;
  final double phase;
  final bool isCrimson;

  const _CyberParticle({
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.speed,
    required this.maxOpacity,
    required this.phase,
    required this.isCrimson,
  });
}

/// Continuous Floating Audio Embers with Zero-Cut Boundary Fade
class _CyberParticlesPainter extends CustomPainter {
  final List<_CyberParticle> particles;
  final double time;

  _CyberParticlesPainter({
    required this.particles,
    required this.time,
  });

  static final Paint _haloPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  static final Paint _corePaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final rawY = (p.baseY - (time * p.speed * 0.15)) % 1.0;
      final currentY = rawY < 0 ? rawY + 1.0 : rawY;
      final edgeFade = sin(currentY * pi).clamp(0.0, 1.0);

      final swayX = (p.baseX + sin(time * 0.8 + p.phase) * 0.04) % 1.0;

      final px = swayX * size.width;
      final py = currentY * size.height;

      final flicker = 0.7 + 0.3 * sin(time * 2.5 + p.phase);
      final finalAlpha = (p.maxOpacity * edgeFade * flicker).clamp(0.0, 1.0);

      final color = p.isCrimson
          ? AppColors.accent.withValues(alpha: finalAlpha)
          : const Color(0xFFFF3344).withValues(alpha: finalAlpha * 0.9);

      final pos = Offset(px, py);

      _haloPaint.color = color.withValues(alpha: finalAlpha * 0.35);
      canvas.drawCircle(pos, p.size * 2.0, _haloPaint);

      _corePaint.color = color;
      canvas.drawCircle(pos, p.size / 2, _corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberParticlesPainter oldDelegate) =>
      oldDelegate.time != time;
}


/// Falling Lead-Colored Japanese Mask Model inside Google Button
class _ButtonMask {
  final double baseX;
  final double baseY;
  final double speed;
  final double size;
  final double maxOpacity;
  final String asset;

  const _ButtonMask({
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.size,
    required this.maxOpacity,
    required this.asset,
  });
}

/// Symmetrically balanced left & right lanes with randomized vertical offsets and speeds
const List<_ButtonMask> _buttonMasks = [
  // --- Left Side Flank (4 masks, evenly spaced lanes, randomized speeds/offsets) ---
  _ButtonMask(
    baseX: 0.05,
    baseY: 0.15,
    speed: 0.24,
    size: 19.0,
    maxOpacity: 0.18,
    asset: 'assets/images/oni.png',
  ),
  _ButtonMask(
    baseX: 0.13,
    baseY: 0.65,
    speed: 0.18,
    size: 18.0,
    maxOpacity: 0.15,
    asset: 'assets/images/hannya.png',
  ),
  _ButtonMask(
    baseX: 0.21,
    baseY: 0.35,
    speed: 0.28,
    size: 20.0,
    maxOpacity: 0.18,
    asset: 'assets/images/tengu.png',
  ),
  _ButtonMask(
    baseX: 0.29,
    baseY: 0.85,
    speed: 0.20,
    size: 17.5,
    maxOpacity: 0.14,
    asset: 'assets/images/oni.png',
  ),

  // --- Right Side Flank (4 masks, matching paired lanes, randomized speeds/offsets) ---
  _ButtonMask(
    baseX: 0.71,
    baseY: 0.45,
    speed: 0.22,
    size: 18.0,
    maxOpacity: 0.15,
    asset: 'assets/images/hannya.png',
  ),
  _ButtonMask(
    baseX: 0.79,
    baseY: 0.10,
    speed: 0.26,
    size: 20.0,
    maxOpacity: 0.18,
    asset: 'assets/images/tengu.png',
  ),
  _ButtonMask(
    baseX: 0.87,
    baseY: 0.75,
    speed: 0.17,
    size: 17.5,
    maxOpacity: 0.14,
    asset: 'assets/images/oni.png',
  ),
  _ButtonMask(
    baseX: 0.95,
    baseY: 0.30,
    speed: 0.25,
    size: 19.0,
    maxOpacity: 0.18,
    asset: 'assets/images/hannya.png',
  ),
];

/// High-Performance Direct Canvas Painter for Falling Masks (Zero Widget Rebuilds, 120 FPS)
class _ButtonMaskPainter extends CustomPainter {
  final double time;
  final ui.Image? oni;
  final ui.Image? hannya;
  final ui.Image? tengu;

  _ButtonMaskPainter({
    required this.time,
    required this.oni,
    required this.hannya,
    required this.tengu,
  });

  static final Paint _maskPaint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (oni == null && hannya == null && tengu == null) return;
    final w = size.width;
    final h = size.height;

    for (final mask in _buttonMasks) {
      ui.Image? img;
      if (mask.asset.contains('oni')) {
        img = oni;
      } else if (mask.asset.contains('hannya')) {
        img = hannya;
      } else if (mask.asset.contains('tengu')) {
        img = tengu;
      }
      if (img == null) continue;

      final rawY = (mask.baseY + (time * mask.speed * 0.35)) % 1.0;
      final edgeFade = sin(rawY * pi).clamp(0.0, 1.0);
      final opacity = (mask.maxOpacity * edgeFade).clamp(0.0, 1.0);
      if (opacity <= 0.01) continue;

      final posX = mask.baseX * (w - mask.size);
      final posY = (rawY * (h + mask.size)) - (mask.size * 0.5);

      _maskPaint.colorFilter = ColorFilter.mode(
        const Color(0xFF2B2F38).withValues(alpha: opacity),
        BlendMode.srcIn,
      );

      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromLTWH(posX, posY, mask.size, mask.size);
      canvas.drawImageRect(img, src, dst, _maskPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonMaskPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.oni != oni ||
      oldDelegate.hannya != hannya ||
      oldDelegate.tengu != tengu;
}


/// Water droplet ripple effect — concentric rings expand from tap point like a drop hitting water
class _ButtonShockwaveRipplePainter extends CustomPainter {
  final double progress;
  final Offset center;

  const _ButtonShockwaveRipplePainter({
    required this.progress,
    required this.center,
  });

  static final Paint _fillPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  static final Paint _ringPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final epicenter = (center == Offset.zero)
        ? Offset(size.width * 0.5, size.height * 0.5)
        : center;

    final maxRadius = min(size.width, size.height) * 0.55;

    // Soft radial fill — surface tension splash
    if (progress < 0.45) {
      final fillProg = progress / 0.45;
      final fillRadius = maxRadius * 0.25 * Curves.easeOutQuart.transform(fillProg);
      final fillAlpha = (1.0 - fillProg) * 0.22;

      _fillPaint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: fillAlpha * 2.5),
          Colors.white.withValues(alpha: fillAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: fillRadius));

      canvas.drawCircle(epicenter, fillRadius, _fillPaint);
    }

    // 5 tight concentric ripple rings
    const ringCount = 5;
    const ringDelay = 0.08;
    for (int i = 0; i < ringCount; i++) {
      final ringStart = i * ringDelay;
      if (progress <= ringStart) continue;

      final ringProgress = ((progress - ringStart) / (1.0 - ringStart)).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(ringProgress);
      final radius = maxRadius * eased;

      final fadeIn = (ringProgress * 6.0).clamp(0.0, 1.0);
      final fadeOut = (1.0 - ringProgress);
      final alpha = fadeIn * fadeOut;

      final thickness = (1.8 - i * 0.2) * fadeOut;
      final ringAlpha = alpha * (1.0 - i * 0.15);

      _ringPaint
        ..color = Colors.white.withValues(alpha: ringAlpha * 0.8)
        ..strokeWidth = thickness;
      canvas.drawCircle(epicenter, radius, _ringPaint);

      if (ringAlpha > 0.05) {
        _ringPaint
          ..color = AppColors.accent.withValues(alpha: ringAlpha * 0.3)
          ..strokeWidth = thickness + 3.0;
        canvas.drawCircle(epicenter, radius, _ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonShockwaveRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center;
}

/// Official 4-Color Google 'G' Vector Painter
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static final Paint _logoPaint = Paint()
    ..color = AppColors.bgDeep
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final p = _logoPaint;

    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.57, 23.685, 10.87, 23.555, 10.2)
      ..lineTo(12.0, 10.2)
      ..lineTo(12.0, 14.71)
      ..lineTo(18.6, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.2, 18.39)
      ..lineTo(16.2, 21.44)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.745, 16.27, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, p);

    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12.0, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.1, 5.28, 14.27)
      ..lineTo(1.25, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, p);

    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.9, 12.78, 4.9, 12.0)
      ..cubicTo(4.9, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.18, 0.0, 9.99, 0.0, 12.0)
      ..cubicTo(0.0, 14.01, 0.45, 15.82, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, p);

    final redPath = Path()
      ..moveTo(12.0, 4.8)
      ..cubicTo(13.77, 4.8, 15.35, 5.41, 16.6, 6.6)
      ..lineTo(20.02, 3.18)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.8, 12.0, 4.8)
      ..close();
    canvas.drawPath(redPath, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

/// Precomputed EMP filament trigonometry vectors for zero paint-time math
class _FilamentVector {
  final double cosVal;
  final double sinVal;
  final double innerOffset;
  final double outerOffset;

  const _FilamentVector({
    required this.cosVal,
    required this.sinVal,
    required this.innerOffset,
    required this.outerOffset,
  });
}

/// Ultra-Cinematic Cyberpunk Red Shockwave Detonation
/// Expands dynamically from the hero orb center across the entire display upon successful authentication.
/// Fully optimized for Zero-GC during rendering and hardware-accelerated composition.
class _ShockwavePainter extends CustomPainter {
  final double progress;
  final Offset epicenter;

  const _ShockwavePainter({
    required this.progress,
    required this.epicenter,
  });

  // Reusable static Paint instances to guarantee ZERO heap allocations / GC churn in paint()
  static final Paint _flashPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _discPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _filamentPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  static final Paint _outerGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;
  static final Paint _coreRingPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _echoPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  static final Paint _subPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _overlayPaint = Paint()..style = PaintingStyle.fill;

  // Precomputed deterministic trigonometry angles for EMP filaments
  static final List<_FilamentVector> _filaments = List.generate(18, (i) {
    final angle = (i / 18.0) * 2 * pi + (sin(i * 1.7) * 0.15);
    return _FilamentVector(
      cosVal: cos(angle),
      sinVal: sin(angle),
      innerOffset: 16.0 + (i % 3) * 8.0,
      outerOffset: 12.0 + (i % 4) * 6.0,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    // Maximum radius: distance from epicenter to furthest screen corner plus buffer
    final maxDistX = max(epicenter.dx, size.width - epicenter.dx);
    final maxDistY = max(epicenter.dy, size.height - epicenter.dy);
    final maxRadius = sqrt(maxDistX * maxDistX + maxDistY * maxDistY) * 1.08;

    // Eased curve for explosive burst: explosive start, powerful momentum
    final curvedProgress = Curves.easeOutCubic.transform(progress);
    final primaryRadius = 69.0 + (maxRadius - 69.0) * curvedProgress;

    // 1. Initial Core Detonation Flash at Epicenter (fades out early)
    if (progress < 0.45) {
      final flashProg = progress / 0.45;
      final flashRadius = 35.0 + 130.0 * Curves.easeOutQuad.transform(flashProg);
      final flashAlpha = (1.0 - flashProg).clamp(0.0, 1.0);

      _flashPaint.shader = RadialGradient(
        colors: [
          const Color(0xFFFF2B2B).withValues(alpha: flashAlpha * 0.95),
          AppColors.accent.withValues(alpha: flashAlpha * 0.70),
          const Color(0xFF8A0005).withValues(alpha: flashAlpha * 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: flashRadius));

      canvas.drawCircle(epicenter, flashRadius, _flashPaint);
    }

    // 2. Volumetric Blast Disc (Energy field filling behind primary wave)
    if (primaryRadius > 20) {
      final discAlpha = (1.0 - (progress * 0.75)).clamp(0.0, 1.0);
      _discPaint.shader = RadialGradient(
        colors: [
          Colors.transparent,
          AppColors.accent.withValues(alpha: 0.04 * discAlpha),
          AppColors.accent.withValues(alpha: 0.18 * discAlpha),
          AppColors.accent.withValues(alpha: 0.35 * discAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 0.88, 0.97, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: primaryRadius));

      canvas.drawCircle(epicenter, primaryRadius, _discPaint);
    }

    // 3. Radial EMP Filaments / Energy Distortion Spikes (along the wavefront)
    if (progress < 0.85) {
      final filamentAlpha = (1.0 - (progress / 0.85)).clamp(0.0, 1.0) * 0.55;
      _filamentPaint.color = AppColors.accent.withValues(alpha: filamentAlpha);

      for (int i = 0; i < 18; i++) {
        final f = _filaments[i];
        final rInner = max(0.0, primaryRadius - f.innerOffset);
        final rOuter = primaryRadius + f.outerOffset;
        canvas.drawLine(
          Offset(epicenter.dx + f.cosVal * rInner, epicenter.dy + f.sinVal * rInner),
          Offset(epicenter.dx + f.cosVal * rOuter, epicenter.dy + f.sinVal * rOuter),
          _filamentPaint,
        );
      }
    }

    // 4. Primary Supersonic Shockwave Ring (Sharp leading edge + Neon Glow)
    final waveAlpha = (1.0 - (progress * 0.35)).clamp(0.0, 1.0);

    // Outer Neon Glow Halo
    _outerGlowPaint.color = AppColors.accent.withValues(alpha: 0.40 * waveAlpha);
    canvas.drawCircle(epicenter, primaryRadius, _outerGlowPaint);

    // Core Crisp Shockwave Stroke
    final strokeWidth = max(1.8, 4.2 * (1.0 - progress * 0.45));
    _coreRingPaint
      ..color = const Color(0xFFFF4040).withValues(alpha: 0.95 * waveAlpha)
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(epicenter, primaryRadius, _coreRingPaint);

    // 5. Secondary Trailing Echo Wave (Follows ~8% behind)
    if (progress > 0.08) {
      final echoProg = Curves.easeOutCubic.transform(
        ((progress - 0.08) / 0.92).clamp(0.0, 1.0),
      );
      final echoRadius = 69.0 + (maxRadius - 69.0) * echoProg;
      final echoAlpha = (1.0 - echoProg).clamp(0.0, 1.0) * 0.65;

      _echoPaint.color = AppColors.accent.withValues(alpha: echoAlpha);
      canvas.drawCircle(epicenter, echoRadius, _echoPaint);
    }

    // 6. Tertiary Sub-Harmonic Wave (Follows ~18% behind)
    if (progress > 0.18) {
      final subProg = Curves.easeOutCubic.transform(
        ((progress - 0.18) / 0.82).clamp(0.0, 1.0),
      );
      final subRadius = 69.0 + (maxRadius - 69.0) * subProg;
      final subAlpha = (1.0 - subProg).clamp(0.0, 1.0) * 0.38;

      _subPaint.color = AppColors.accent.withValues(alpha: subAlpha);
      canvas.drawCircle(epicenter, subRadius, _subPaint);
    }

    // 7. Full Screen Deep Crimson / Shadow Takeover for Seamless Transition
    if (progress > 0.50) {
      final fadeProg = Curves.easeInQuad.transform(
        ((progress - 0.50) / 0.50).clamp(0.0, 1.0),
      );
      _overlayPaint.color = const Color(0xFF0F0203).withValues(alpha: fadeProg);
      canvas.drawPaint(_overlayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.epicenter != epicenter;
  }
}

class _PulseDotPainter extends CustomPainter {
  final double time;
  const _PulseDotPainter({required this.time});

  static final Paint _dotPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = sin(time * 2.5) * 0.5 + 0.5;
    _glowPaint.color = AppColors.accent.withValues(alpha: 0.25 + 0.25 * pulse);
    canvas.drawCircle(center, 5.0, _glowPaint);
    _dotPaint.color = AppColors.accent;
    canvas.drawCircle(center, 3.0, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseDotPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _FooterDot extends StatelessWidget {
  final Color color;
  const _FooterDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.7),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

