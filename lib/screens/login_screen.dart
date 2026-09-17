import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_strings.dart';
import '../widgets/cyber_orb.dart';
import '../widgets/cyber_glitch_text.dart';
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
  late final AnimationController _rippleController;
  final GlobalKey _orbKey = GlobalKey();
  Offset? _cachedOrbCenter;
  double _time = 0.0;
  bool _isLoading = false;
  bool _loginSuccess = false;
  Offset _buttonTapLocal = Offset.zero;

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
        if (auth.uid != null) {
          context.read<LibraryProvider>().connectToFirestore(auth.uid!);
        }
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });

    // Single-shot tactile shockwave burst inside Google button on tap (~550ms)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Continuous monotonic ticker: NEVER wraps, NEVER resets, ZERO jump cuts!
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _time = elapsed.inMicroseconds / 1000000.0;
        });
      }
    });
    _ticker.start();
  }

  void _handleGuestExplore() {
    final auth = context.read<AuthProvider>();
    auth.loginAsGuest();
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
    _shockwaveController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
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
        final locale = context.read<LocaleProvider>();
        final strings = locale.strings;
        final msg = strings.loginGoogleError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flash_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: locale.getTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        );
      }
    }
  }
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
    final t = _time;
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // 1. Cyber Grid Matrix Background
          Positioned.fill(
            child: CustomPaint(painter: const _CyberGridPainter()),
          ),

          // 2. Continuous Drifting Cyber Audio Particles (Zero Jump Cuts)
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberParticlesPainter(
                particles: _particles,
                time: t,
              ),
            ),
          ),

          // 3. Ambient Breathing Plasma Glow Behind Center Orb
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.12,
            width: size.width * 0.76,
            height: size.width * 0.76,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    radius: 0.52 + 0.12 * sin(t * 1.8),
                    colors: [
                      AppColors.accent.withValues(
                        alpha: 0.26 + 0.08 * sin(t * 1.8),
                      ),
                      AppColors.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
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
                  _buildHudTopBar(t, locale, strings),

                  const Spacer(flex: 3),

                  // Center 3D Plasma Holographic Orb with Radial Audio Equalizer
                  _buildHeroEmblem(t),

                  const SizedBox(height: 16),

                  // Cyberpunk Neon Typography
                  _buildBrandingHeader(t, locale, strings),

                  const Spacer(flex: 3),

                  // Cyberpunk Neural Link Google Button
                  _buildCyberAuthCard(t, locale, strings),

                  const Spacer(flex: 2),

                  // Company Brand Footer
                  _buildCompanyFooter(t),

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
  Widget _buildHudTopBar(double t, LocaleProvider locale, AppStrings strings) {
    final pulse = (sin(t * 2.5) * 0.5 + 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Identity with Glowing Cyber Dot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4 + 0.4 * pulse),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
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
                  'v3.0',
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

          // Right: Action Chip to Explore Catalog as Guest
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleGuestExplore,
              borderRadius: BorderRadius.circular(20),
              splashColor: AppColors.accent.withValues(alpha: 0.25),
              highlightColor: AppColors.accent.withValues(alpha: 0.12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.loginGuestExplore,
                      style: locale.getTextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Company Brand Footer: Fixed Dots & Shimmering Words ---
  Widget _buildCompanyFooter(double t) {
    // Left dot: Cyber Red, Right dot: Electric Blue (Fixed colors, no carousel)
    const leftColor = Color(0xFFFF1919);
    const rightColor = Color(0xFF00D4FF);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left LED Dot (Color and glow remain constant)
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: leftColor,
            boxShadow: [
              BoxShadow(
                color: leftColor.withValues(alpha: 0.7),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Brand typography with gentle moving gradient wave across the letters
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            // Smooth moving gradient wave strictly from Cyber Red to Electric Blue (slower, silky-smooth shift)
            final shift = sin(t * 0.6) * 0.35;
            return LinearGradient(
              begin: Alignment(-1.1 + shift, 0.0),
              end: Alignment(1.1 + shift, 0.0),
              colors: const [
                Color(0xFFFF1919), // Cyber Red
                Color(0xFFFF2B40), // Vibrant Red
                Color(0xFF0099FF), // Vivid Cyber Blue
                Color(0xFF00D4FF), // Electric Cyber Blue
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

        // Right LED Dot (Color and glow remain constant)
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: rightColor,
            boxShadow: [
              BoxShadow(
                color: rightColor.withValues(alpha: 0.7),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Hero Centerpiece with 360-Degree Radial Equalizer Waveform ---
  Widget _buildHeroEmblem(double t) {
    return SizedBox(
      key: _orbKey,
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Dynamic 360-Degree Harmonic Equalizer Bars (Around Central Orb)
          Positioned.fill(
            child: CustomPaint(
              painter: _RadialSoundWavePainter(time: t),
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
  Widget _buildBrandingHeader(double t, LocaleProvider locale, AppStrings strings) {
    final pulse = (sin(t * 3.0) * 0.5 + 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Title
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.9),
                AppColors.accent.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: Row(
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
                      color: AppColors.accent.withValues(alpha: 0.5 + 0.3 * pulse),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  // --- Cyberpunk Neural Link Google Button ---
  Widget _buildCyberAuthCard(double t, LocaleProvider locale, AppStrings strings) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.32),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 1. Cyberpunk Red & Crimson Gradient
            Container(
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFFF1919),
                    Color(0xFFE50914),
                    Color(0xFF9E0B0B),
                  ],
                ),
              ),
            ),

            // 2. Falling Lead-Colored Japanese Masks (Oni, Hannya, Tengu) inside button
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: _buttonMasks.map((mask) {
                        // Falling straight down (normalized Y: 0.0 -> 1.0)
                        final rawY = (mask.baseY + (t * mask.speed * 0.35)) % 1.0;
                        // Smooth sine boundary fade (Zero pop or cuts)
                        final edgeFade = sin(rawY * pi).clamp(0.0, 1.0);
                        final opacity = mask.maxOpacity * edgeFade;

                        if (opacity <= 0.01) return const SizedBox.shrink();

                        // Falls completely straight down (no sway, no rotation)
                        final posX = mask.baseX * (w - mask.size);
                        final posY = (rawY * (h + mask.size)) - (mask.size * 0.5);

                        return Positioned(
                          left: posX,
                          top: posY,
                          child: Image.asset(
                            mask.asset,
                            width: mask.size,
                            height: mask.size,
                            fit: BoxFit.contain,
                            color: const Color(0xFF2B2F38).withValues(alpha: opacity),
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),

            // 3. Slower, Less Frequent Luxurious Shimmer Sheen
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ContinuousShimmerPainter(time: t),
                ),
              ),
            ),

            // 4. Cyberpunk Ripple Shockwave (Tactile Feedback on Tap)
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
                        painter: _ButtonRipplePainter(
                          progress: _rippleController.value,
                          center: _buttonTapLocal,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Button Interaction
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                if (_isLoading || _loginSuccess) return;
                _buttonTapLocal = details.localPosition;
                _rippleController.forward(from: 0.0);
              },
              onTap: () {
                if (_isLoading || _loginSuccess) return;
                _handleGoogleLogin();
              },
              child: SizedBox(
                height: 54,
                child: _loginSuccess
                    ? Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              strings.loginGranted,
                              style: locale.getTextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                      )
                    : AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _isLoading ? 0.35 : 1.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google Official 4-Color Emblem
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
                              strings.loginGoogle,
                              style: locale.getTextStyle(
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const barCount = 48;

    // 1. Subwoofer Bass Heartbeat (Organic rhythmic pulse on the baseline orbit)
    final bassPulse = pow(max(0.0, sin(time * 3.2)), 4.0) * 2.2;
    final baseRadius = 76.0 + bassPulse;

    // 2. Active Baseline Orbit Track Rings (Pure Crimson Neon)
    final trackPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.22 + (bassPulse * 0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawCircle(center, baseRadius, trackPaint);

    final innerGlowRing = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    canvas.drawCircle(center, baseRadius - 2.5, innerGlowRing);

    // 3. Ambient Fluid Harmonic Wave Ribbon (Ethereal acoustic contour behind the bars)
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

    // Draw Ambient Wave Ribbon Glow
    canvas.drawPath(
      ribbonPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = AppColors.accent.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 4. 48 High-Fidelity Symmetrical Equalizer Capsule Bars
    for (int i = 0; i < barCount; i++) {
      final theta = (i / barCount) * 2 * pi;
      final isPrimary = (i % 2 == 0);

      // Acoustic stereo-interference harmonics (moving clockwise & counter-clockwise)
      final wave1 = sin((time * 3.6) + (theta * 3.0));
      final wave2 = cos((-time * 4.6) + (theta * 2.0));
      final wave3 = sin((time * 1.8) - (theta * 4.0));
      final wave4 = cos((time * 6.0) + (theta * 1.0)) * 0.15;

      final raw = ((wave1 * 0.40 + wave2 * 0.36 + wave3 * 0.24 + wave4) + 1.0) / 2.0;

      // Primary bars reach higher; companion bars give rhythm & syncopation
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

      // Mirrored inner micro-reflection into the dark glass zone
      final pInnerEnd = Offset(
        center.dx + cosT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
        center.dy + sinT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
      );

      final barThickness = isPrimary ? 3.0 : 2.0;

      // Pass A: Mirrored Inner Acoustic Reflection
      canvas.drawLine(
        pStart,
        pInnerEnd,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.16)
          ..strokeWidth = barThickness * 0.8
          ..strokeCap = StrokeCap.round,
      );

      // Pass B: Wide Volumetric Crimson Glow Bloom
      canvas.drawLine(
        pStart,
        pEnd,
        Paint()
          ..color = AppColors.accent.withValues(alpha: isPrimary ? 0.35 : 0.20)
          ..strokeWidth = barThickness + 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );

      // Pass C: Core Equalizer Capsule Bar with Pure Crimson Gradient (100% Red, NO white)
      final barShader = LinearGradient(
        colors: [
          const Color(0xFF55000A), // Deep Blood Ruby Base Anchor
          AppColors.accent,        // Cyber Crimson Red (#FF1919)
          const Color(0xFFFF2B40), // Vibrant Electric Red
          const Color(0xFFFF485B), // Brilliant Crimson-Scarlet Crest Tip
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromPoints(pStart, pEnd));

      canvas.drawLine(
        pStart,
        pEnd,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = barThickness
          ..strokeCap = StrokeCap.round
          ..shader = barShader,
      );

      // Pass D: Intense Red Core Beam for High-Energy Peaks
      if (raw > 0.65 && isPrimary) {
        final highlightFraction = ((raw - 0.65) / 0.35).clamp(0.0, 1.0);
        final pMid = Offset.lerp(pStart, pEnd, 0.55)!;
        canvas.drawLine(
          pMid,
          pEnd,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFF6677).withValues(alpha: 0.70 * highlightFraction),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialSoundWavePainter oldDelegate) =>
      oldDelegate.time != time;
}

/// Cyber Grid Painter with Tech Crosshairs
class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 44.0;

    final linePaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final crossPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.13)
      ..strokeWidth = 0.8;
    const crossSize = 3.0;

    for (double x = spacing; x < size.width; x += spacing * 2) {
      for (double y = spacing; y < size.height; y += spacing * 2) {
        canvas.drawLine(Offset(x - crossSize, y), Offset(x + crossSize, y), crossPaint);
        canvas.drawLine(Offset(x, y - crossSize), Offset(x, y + crossSize), crossPaint);
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

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Linear drift over continuous time
      final rawY = (p.baseY - (time * p.speed * 0.15)) % 1.0;
      final currentY = rawY < 0 ? rawY + 1.0 : rawY;

      // Crucial: sin(currentY * pi) ensures particles fade smoothly to 0 at edges.
      // This mathematically ELIMINATES any jump cut or pop!
      final edgeFade = sin(currentY * pi).clamp(0.0, 1.0);

      // Smooth horizontal sine sway
      final swayX = (p.baseX + sin(time * 0.8 + p.phase) * 0.04) % 1.0;

      final px = swayX * size.width;
      final py = currentY * size.height;

      final flicker = 0.7 + 0.3 * sin(time * 2.5 + p.phase);
      final finalAlpha = (p.maxOpacity * edgeFade * flicker).clamp(0.0, 1.0);

      final color = p.isCrimson
          ? const Color(0xFFFF1919).withValues(alpha: finalAlpha)
          : const Color(0xFFFF3344).withValues(alpha: finalAlpha * 0.9);

      // Glow halo
      canvas.drawCircle(
        Offset(px, py),
        p.size * 2.0,
        Paint()
          ..color = color.withValues(alpha: finalAlpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      // Core particle
      canvas.drawCircle(
        Offset(px, py),
        p.size / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
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

/// Continuous Shimmer Wave for the Cyber Button (Slow, Luxurious Periodic Sheen)
class _ContinuousShimmerPainter extends CustomPainter {
  final double time;

  _ContinuousShimmerPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Cycle every 7.5 seconds (slower and less frequent)
    final cycle = time % 7.5;
    if (cycle > 3.2) return; // Sweeps gently for 3.2s, then 4.3s of calm

    final progress = cycle / 3.2; // 0.0 -> 1.0
    final smoothProgress = (1.0 - cos(progress * pi)) / 2.0;
    final shimmerX = (smoothProgress * (size.width + 160)) - 80;

    final rect = Rect.fromLTWH(shimmerX - 50, 0, 100, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ContinuousShimmerPainter oldDelegate) =>
      oldDelegate.time != time;
}

/// Cyberpunk Ripple Shockwave inside the Google Auth Button
/// Emanates small, localized concentric EMP rings from the tap epicenter.
/// Ultra-optimized for 120 FPS: zero allocations in paint() using static cached Paints.
class _ButtonRipplePainter extends CustomPainter {
  final double progress;
  final Offset center;

  const _ButtonRipplePainter({required this.progress, required this.center});

  // Reusable static Paint objects to guarantee 0 allocations during animation loop
  static final Paint _glowPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  static final Paint _ringPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Fallback to button center if touch coordinate is zero or unset
    final epicenter = (center == Offset.zero)
        ? Offset(size.width * 0.5, size.height * 0.5)
        : center;

    // Compact, localized shockwave radius (~36px max radius, tight to the touch point)
    final maxRadius = (size.height * 0.68).clamp(30.0, 38.0);

    // 2 staggered concentric EMP rings with smooth quadratic decay (single-shot burst)
    for (int i = 0; i < 2; i++) {
      final p = progress - (i * 0.25);
      if (p <= 0.0 || p >= 1.0) continue;

      // Fast quadratic ease-out without allocating curve objects: p * (2.0 - p)
      final easePhase = p * (2.0 - p);
      final radius = maxRadius * easePhase;
      final fade = 1.0 - p;

      if (fade <= 0.04) continue;

      // 1. Soft Crimson Energy Halo (Wider stroke, zero MaskFilter overhead)
      _glowPaint
        ..color = const Color(0xFFFF1919).withValues(alpha: fade * 0.35)
        ..strokeWidth = 3.2 * fade;
      canvas.drawCircle(epicenter, radius, _glowPaint);

      // 2. White-Hot Crisp Core Ring
      _ringPaint
        ..color = Colors.white.withValues(alpha: fade * 0.65)
        ..strokeWidth = 1.2 * fade;
      canvas.drawCircle(epicenter, radius, _ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center;
}

/// Official 4-Color Google 'G' Vector Painter
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue: #4285F4
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
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
    canvas.drawPath(bluePath, bluePaint);

    // Green: #34A853
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
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
    canvas.drawPath(greenPath, greenPaint);

    // Yellow: #FBBC05
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
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
    canvas.drawPath(yellowPath, yellowPaint);

    // Red: #EA4335
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.8)
      ..cubicTo(13.77, 4.8, 15.35, 5.41, 16.6, 6.6)
      ..lineTo(20.02, 3.18)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.8, 12.0, 4.8)
      ..close();
    canvas.drawPath(redPath, redPaint);

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
    ..strokeWidth = 10.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
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



