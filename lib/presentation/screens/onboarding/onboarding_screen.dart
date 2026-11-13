library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../state/app_providers.dart';
import '../../state/locale_provider.dart';
import '../../widgets/cyber_glitch_text.dart';
import '../../widgets/cyber_nav_icon.dart';
import '../../widgets/haptics.dart';

part 'painters.dart';
part 'slide_identity.dart';
part 'slide_player.dart';
part 'slide_search.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final Ticker _ticker;
  final ValueNotifier<double> _timeNotifier = ValueNotifier<double>(0.0);
  int _currentPage = 0;

  late final List<_OnboardingParticle> _particles;

  static const _vinylMasks = [
    'assets/images/oni.png',
    'assets/images/hannya.png',
    'assets/images/tengu.png',
  ];
  late final String _selectedVinylMask;

  bool _reduceMotion = false;
  bool _tickerConfigured = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final rng = Random(42);
    _particles = List.generate(24, (_) => _OnboardingParticle(rng));
    _selectedVinylMask = _vinylMasks[Random().nextInt(_vinylMasks.length)];

    _ticker = createTicker((elapsed) {
      if (mounted) {
        _timeNotifier.value = elapsed.inMicroseconds / 1000000.0;
      }
    });
  }

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

  @override
  void dispose() {
    _pageController.dispose();
    _ticker.dispose();
    _timeNotifier.dispose();
    super.dispose();
  }

  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    _isCompleting = true;

    await ref.read(sessionGateProvider).saveOnboardingDone();
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

    // First run: the router moves on to the main screen.
    ref.read(sessionGateProvider).onboardingCompleted();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: AppMotion.slow,
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
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
            top: size.height * 0.15,
            left: size.width * 0.15,
            width: size.width * 0.7,
            height: size.width * 0.7,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _timeNotifier,
                  builder: (context, t, _) {
                    return Container(
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
                    );
                  },
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                RepaintBoundary(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _timeNotifier,
                    builder: (context, t, _) => _buildTopBar(t, locale, strings),
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _IdentitySlide(
                        timeNotifier: _timeNotifier,
                        size: size,
                        locale: locale,
                        strings: strings,
                        selectedVinylMask: _selectedVinylMask,
                      ),
                      _AnimatedSlide(
                        timeNotifier: _timeNotifier,
                        builder: (t) => _buildSlide2Search(size, t, locale, strings),
                      ),
                      _AnimatedSlide(
                        timeNotifier: _timeNotifier,
                        builder: (t) => _buildSlide3Player(size, t, locale, strings),
                      ),
                    ],
                  ),
                ),

                RepaintBoundary(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _timeNotifier,
                    builder: (context, t, _) => _buildBottomControls(t, locale, strings),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double t, LocaleProvider locale, AppStrings strings) {
    final pulse = (sin(t * 2.5) * 0.5 + 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.onboardingHeaderPrefix,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.micro,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 1.8,
                    ),
                  ),
                  CyberGlitchText(
                    text: strings.onboardingHeaderGlitch,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.micro,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Semantics(
            button: true,
            label: strings.onboardingSkip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () { Haptics.tap(); _completeOnboarding(); },
              borderRadius: BorderRadius.circular(AppRadius.sheet),
              splashColor: AppColors.accent.withValues(alpha: 0.2),
              highlightColor: AppColors.accent.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.sheet),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.onboardingSkip,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.fast_forward_rounded,
                        size: 11,
                        color: AppColors.textMuted,
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
    );
  }

  Widget _buildBottomControls(double t, LocaleProvider locale, AppStrings strings) {
    final isLastPage = _currentPage == 2;
    final pulse = sin(t * 3.0) * 0.5 + 0.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: AppMotion.normal,
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
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

          Semantics(
            button: true,
            label: isLastPage ? strings.onboardingStart : strings.onboardingNext,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () { Haptics.tap(); _nextPage(); },
              borderRadius: BorderRadius.circular(AppRadius.card),
              splashColor: AppColors.accent.withValues(alpha: 0.3),
              highlightColor: AppColors.accent.withValues(alpha: 0.15),
              child: AnimatedContainer(
                duration: AppMotion.normal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isLastPage ? AppColors.accent : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppRadius.card),
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
                      isLastPage ? strings.onboardingStart : strings.onboardingNext,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w900,
                        color: isLastPage ? Colors.white : AppColors.textBright,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: Icon(
                        isLastPage
                            ? Icons.play_arrow_rounded
                            : Icons.arrow_forward_rounded,
                        size: 16,
                        color: isLastPage ? Colors.white : AppColors.accent,
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
    );
  }
}

Widget _buildTechPill(IconData? icon, String text, [LocaleProvider? locale, Widget? customIcon]) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.bgCard.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      border: Border.all(
        color: AppColors.border.withValues(alpha: 0.6),
        width: 0.7,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (customIcon != null)
          customIcon
        else if (icon != null)
          ExcludeSemantics(child: Icon(icon, size: 12, color: AppColors.accent)),
        const SizedBox(width: 5),
        Text(
          text,
          style: locale?.getTextStyle(
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ) ??
              GoogleFonts.plusJakartaSans(
                fontSize: AppFontSize.micro,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
        ),
      ],
    ),
  );
}
