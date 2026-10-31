library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../navigation/app_router.dart';
import '../../state/app_providers.dart';
import '../../state/locale_provider.dart';
import '../../widgets/cyber_glitch_text.dart';
import '../../widgets/cyber_orb.dart';
import '../../widgets/spectrum_wave_visualizer.dart';

part 'google_button.dart';
part 'painters.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _shockwaveController;
  final GlobalKey _orbKey = GlobalKey();
  Offset? _cachedOrbCenter;
  final ValueNotifier<double> _timeNotifier = ValueNotifier<double>(0.0);
  bool _isLoading = false;
  bool _loginSuccess = false;

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

    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _shockwaveController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        final auth = ref.read(authProvider);
        if (auth.uid != null && !auth.isGuest) {
          final uid = auth.uid!;
          ref.read(libraryProvider).connectToFirestore(uid);
          final playlists = ref.read(playlistProvider);
          final guestUid = auth.takeGuestUidToMigrate();
          playlists.connectToFirestore(uid).then((_) {
            if (guestUid != null) playlists.importGuestPlaylists(guestUid);
          });
        }
        _navigateAfterLogin();
      }
    });

    _ticker = createTicker((elapsed) {
      if (mounted) {
        _timeNotifier.value = elapsed.inMicroseconds / 1000000.0;
      }
    });
  }

  bool _reduceMotion = false;
  bool _tickerConfigured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tickerConfigured) {
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      if (!_reduceMotion) {
        _ticker.start();
      }
      _tickerConfigured = true;
    }
  }

  /// The router takes it from here: the tutorial for a new account, the
  /// main screen otherwise (or the page a link pointed to).
  void _navigateAfterLogin() {
    if (mounted) context.go(AppPaths.home);
  }

  Future<void> _handleGuestExplore() async {
    final auth = ref.read(authProvider);
    await auth.loginAsGuest();
    if (!mounted) return;
    context.go(AppPaths.home);
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
    final auth = ref.read(authProvider);
    final success = await auth.loginWithGoogle();
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
          final locale = ref.read(localeProvider);
          final strings = locale.strings;
          final msg = auth.authError == 'login_throttled'
              ? strings.loginThrottled
              : strings.loginGoogleError;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 18, semanticLabel: strings.a11yLoginError),
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
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _CyberGridPainter()),
          ),

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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  _buildHudTopBar(locale, strings),

                  const Spacer(flex: 3),

                  _buildHeroEmblem(),

                  const SizedBox(height: 16),

                  _buildBrandingHeader(locale, strings),

                  const Spacer(flex: 3),

                  _CyberGoogleButton(
                    onPressed: _handleGoogleLogin,
                    isLoading: _isLoading,
                    loginSuccess: _loginSuccess,
                    timeListenable: _timeNotifier,
                    locale: locale,
                    strings: strings,
                  ),

                  const SizedBox(height: 14),

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

  Widget _buildHudTopBar(LocaleProvider locale, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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

  Widget _buildHeroEmblem() {
    return SizedBox(
      key: _orbKey,
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
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

  Widget _buildBrandingHeader(LocaleProvider locale, AppStrings strings) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
