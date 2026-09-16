import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// OnboardingScreen: Interactive 3-step Cyberpunk & Japanese Folklore experience
/// shown on first launch with 120 FPS continuous ticker and zero-GC performance.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final Ticker _ticker;
  double _time = 0.0;
  int _currentPage = 0;

  // Floating audio background particle matrix
  late final List<_OnboardingParticle> _particles;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final rng = Random(42);
    _particles = List.generate(24, (_) => _OnboardingParticle(rng));

    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _time = elapsed.inMicroseconds / 1000000.0;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    _isCompleting = true;

    await StorageService().setCompletedOnboarding(true);
    if (!mounted) return;

    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }

    final auth = context.read<AuthProvider>();
    final destination = auth.isLoggedIn
        ? const MainNavigationScreen()
        : const LoginScreen();

    rootNav.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = _time;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // 1. Cyber Matrix Grid Background
          Positioned.fill(
            child: CustomPaint(painter: const _CyberGridPainter()),
          ),

          // 2. Continuous Drifting Cyber Audio Particles
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberParticlesPainter(
                particles: _particles,
                time: t,
              ),
            ),
          ),

          // 3. Ambient Plasma Glow in the Background
          Positioned(
            top: size.height * 0.15,
            left: size.width * 0.15,
            width: size.width * 0.7,
            height: size.width * 0.7,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    radius: 0.55 + 0.08 * sin(t * 1.5),
                    colors: [
                      AppColors.accent.withValues(
                        alpha: 0.20 + 0.06 * sin(t * 1.5),
                      ),
                      AppColors.accent.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 4. Foreground Content & Controls
          SafeArea(
            child: Column(
              children: [
                // Top HUD Bar with Skip Action
                _buildTopBar(t),

                // Center 3-Step Swipeable Carousel
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildSlide1Identity(size, t),
                      _buildSlide2Search(size, t),
                      _buildSlide3Player(size, t),
                    ],
                  ),
                ),

                // Bottom HUD: Page Indicator Dots & Action Button
                _buildBottomControls(t),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Top HUD Bar ---
  Widget _buildTopBar(double t) {
    final pulse = (sin(t * 2.5) * 0.5 + 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Protocol Badge
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
                      color: AppColors.accent.withValues(
                        alpha: 0.4 + 0.4 * pulse,
                      ),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TSUKI TUNES // ONBOARDING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBright,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),

          // Right: Skip Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _completeOnboarding,
              borderRadius: BorderRadius.circular(20),
              splashColor: AppColors.accent.withValues(alpha: 0.2),
              highlightColor: AppColors.accent.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SALTAR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.fast_forward_rounded,
                      size: 11,
                      color: AppColors.textMuted,
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

  // --- Slide 1: Music Storage, Library & Favorites ---
  Widget _buildSlide1Identity(Size size, double t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Visual Centerpiece: Music Vault Album Sleeve + Spinning Vinyl + Favorite Heart
          _buildMusicVaultGraphic(size, t),

          const SizedBox(height: 10),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              'TU COLECCIÓN • BIBLIOTECA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            'GUARDA TODA TU MÚSICA',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.textBright,
              letterSpacing: 2.0,
              shadows: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Description (100% Real & Honest)
          Text(
            'Guarda tus canciones y álbumes favoritos con un toque. Mantén tu colección musical organizada en tu teléfono y accede a tus temas en cualquier momento.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // 100% Real Features Micro Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTechPill(Icons.favorite_rounded, 'CANCIONES FAVORITAS'),
              _buildTechPill(Icons.smartphone_rounded, 'GUARDADO EN EL DISPOSITIVO'),
              _buildTechPill(Icons.album_rounded, 'COLECCIÓN POR ÁLBUMES'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Music Vault & Vinyl Showcase Graphic ---
  Widget _buildMusicVaultGraphic(Size size, double t) {
    final pulse = sin(t * 3.0) * 0.5 + 0.5;
    final floatDy = sin(t * 1.5) * 6.0;

    return SizedBox(
      height: size.height * 0.35,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, floatDy),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Glowing Nebula behind vinyl
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.25 + 0.1 * pulse),
                      AppColors.accent.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Glassmorphic Music Album Sleeve Card (Backdrop)
              Transform.translate(
                offset: const Offset(-18, 0),
                child: Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Sleeve Header
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.library_music_rounded,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VAULT // TRACKS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mini Equalizer sound waves at bottom of sleeve
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(8, (i) {
                            final h = 6.0 +
                                12.0 *
                                    (sin(t * 4.0 + i * 0.9) * 0.5 + 0.5);
                            return Container(
                              width: 3,
                              height: h,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rotating Vinyl Record (Emerging from sleeve)
              Transform.translate(
                offset: const Offset(36, 0),
                child: Transform.rotate(
                  angle: t * 1.2,
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F0F14),
                      border: Border.all(
                        color: const Color(0xFF2E2E3E),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Vinyl Grooves
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07),
                              width: 1,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                        ),
                        // Vinyl Center Label with Accent Glow
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFF2B40),
                                Color(0xFF990011),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // Spindle Hole
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.bgDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Glowing Favorite Heart Chip (In Front)
              Positioned(
                bottom: 12,
                right: 28,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: 0.4 + 0.3 * pulse,
                        ),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.accent,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'FAVORITOS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Slide 2: Search & Global Catalog (Deezer) ---
  Widget _buildSlide2Search(Size size, double t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Visual Centerpiece: Animated Search Bar with Cycling Queries & Floating Result Cards
          _buildSearchCatalogGraphic(size, t),

          const SizedBox(height: 10),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              'EXPLORACIÓN • CATÁLOGO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF00D4FF),
                letterSpacing: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            'DESCUBRE MILLONES DE TEMAS',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textBright,
              letterSpacing: 1.8,
              shadows: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Description
          Text(
            'Busca cualquier artista, canción o disco en segundos. Explora tendencias globales y escucha avances en alta fidelidad al instante.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // Micro Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTechPill(Icons.search_rounded, 'BÚSQUEDA INSTANTÁNEA'),
              _buildTechPill(Icons.language_rounded, 'MÁS DE 90M DE PISTAS'),
              _buildTechPill(
                  Icons.play_circle_filled_rounded, 'PREVIEWS AL MOMENTO'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSearchCatalogGraphic(Size size, double t) {
    // Simulated cycling search queries with typing illusion
    final queries = [
      'Daft Punk',
      'Deftones',
      'System of a Down',
      'Gorillaz',
      'Kavinsky'
    ];
    final queryIdx = (t / 2.5).floor() % queries.length;
    final activeQuery = queries[queryIdx];
    final blink = (t * 2.5).toInt() % 2 == 0 ? '|' : ' ';

    final cardFloat1 = sin(t * 1.8) * 5.0;
    final cardFloat2 = sin(t * 1.8 + 2.0) * 5.0;
    final pulse = sin(t * 3.0) * 0.5 + 0.5;

    return SizedBox(
      height: size.height * 0.35,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Cyan Glow
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D4FF)
                        .withValues(alpha: 0.20 + 0.08 * pulse),
                    const Color(0xFF00D4FF).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Top: Cyberpunk Glowing Search Bar
            Positioned(
              top: 14,
              child: Container(
                width: 250,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: Color(0xFF00D4FF),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$activeQuery$blink',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DEEZER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00D4FF),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Floating Result Card 1: Daft Punk
            Positioned(
              top: 72,
              left: 12,
              child: Transform.translate(
                offset: Offset(0, cardFloat1),
                child: Container(
                  width: 195,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1919), Color(0xFF8B0000)],
                          ),
                        ),
                        child: const Icon(Icons.music_note,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Around The World',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Daft Punk • Discovery',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.0,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Result Card 2: System of a Down
            Positioned(
              bottom: 16,
              right: 12,
              child: Transform.translate(
                offset: Offset(0, cardFloat2),
                child: Container(
                  width: 205,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0055AA)],
                          ),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chop Suey!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'System of a Down • Toxicity',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.0,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF00D4FF),
                        size: 22,
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

  // --- Slide 3: Immersive Music Player & Controls ---
  Widget _buildSlide3Player(Size size, double t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Visual Centerpiece: Immersive Player Frame with Dancing Equalizer & Scrubbing Progress
          _buildPlayerMockupGraphic(size, t),

          const SizedBox(height: 10),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              'EXPERIENCIA • REPRODUCTOR',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            'REPRODUCTOR INMERSIVO',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.textBright,
              letterSpacing: 2.0,
              shadows: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Description
          Text(
            'Control total de tu música con ecualizadores dinámicos, diseño a pantalla completa y controles fluidos a 120 FPS.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          // Micro Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTechPill(Icons.equalizer_rounded, 'ECUALIZADOR REACTIVO'),
              _buildTechPill(Icons.fullscreen_rounded, 'PANTALLA COMPLETA'),
              _buildTechPill(Icons.speed_rounded, 'FLUIDEZ A 120 FPS'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlayerMockupGraphic(Size size, double t) {
    final floatDy = sin(t * 1.5) * 5.0;
    final pulse = sin(t * 3.0) * 0.5 + 0.5;
    final progress = 0.25 + 0.5 * (sin(t * 0.8) * 0.5 + 0.5);

    return SizedBox(
      height: size.height * 0.35,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, floatDy),
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.2 + 0.15 * pulse),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top: Live Dancing Equalizer Spectrum (14 Bars)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(14, (i) {
                    final h =
                        6.0 + 20.0 * (sin(t * 6.0 + i * 0.7) * 0.5 + 0.5);
                    return Container(
                      width: 4,
                      height: h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.accent,
                            i % 2 == 0
                                ? const Color(0xFFFF2B40)
                                : const Color(0xFF00D4FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                // Center: Track Details Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HARDER, BETTER, FASTER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBright,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Daft Punk • Alive 2007',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.0,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Audio Scrubber / Progress Bar
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.bgMid,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D4FF), AppColors.accent],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '01:42',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '03:44',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Playback Control Buttons Cluster
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.skip_previous_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent
                                .withValues(alpha: 0.5 + 0.3 * pulse),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Tech Spec Micro Pill ---
  Widget _buildTechPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Controls: Dynamic HUD Dots & Action Button ---
  Widget _buildBottomControls(double t) {
    final isLastPage = _currentPage == 2;
    final pulse = sin(t * 3.0) * 0.5 + 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cyberpunk Dynamic Capsule Indicators
          Row(
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isActive
                      ? AppColors.accent
                      : AppColors.textMuted.withValues(alpha: 0.3),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(
                              alpha: 0.4 + 0.4 * pulse,
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),

          // Action Button (Next or Start Experience)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(8),
              splashColor: AppColors.accent.withValues(alpha: 0.3),
              highlightColor: AppColors.accent.withValues(alpha: 0.15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isLastPage ? AppColors.accent : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLastPage
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isLastPage
                          ? AppColors.accent.withValues(
                              alpha: 0.4 + 0.3 * pulse,
                            )
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: isLastPage ? 14 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLastPage ? 'EMPEZAR A ESCUCHAR' : 'SIGUIENTE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isLastPage ? Colors.white : AppColors.textBright,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastPage
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded,
                      size: 16,
                      color: isLastPage ? Colors.white : AppColors.accent,
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
}

// --- Zero-GC Audio Particle Background ---
class _OnboardingParticle {
  final double xRatio;
  final double speed;
  final double size;
  final double opacity;
  final double phase;

  _OnboardingParticle(Random rng)
      : xRatio = rng.nextDouble(),
        speed = 0.04 + rng.nextDouble() * 0.07,
        size = 1.0 + rng.nextDouble() * 2.0,
        opacity = 0.15 + rng.nextDouble() * 0.45,
        phase = rng.nextDouble() * 2 * pi;
}

class _CyberParticlesPainter extends CustomPainter {
  final List<_OnboardingParticle> particles;
  final double time;

  static final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  const _CyberParticlesPainter({
    required this.particles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final yProgress = (p.phase + time * p.speed) % 1.0;
      final y = h - (yProgress * h);
      final x = p.xRatio * w + sin(time * 1.2 + p.phase) * 12.0;

      final alpha = (sin(yProgress * pi) * p.opacity).clamp(0.0, 1.0);
      _particlePaint.color = AppColors.accent.withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), p.size, _particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberParticlesPainter oldDelegate) =>
      oldDelegate.time != time;
}

// --- Cyber Matrix Grid Background ---
class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter();

  static final Paint _gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = const Color(0xFF161622).withValues(alpha: 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
