part of 'onboarding_screen.dart';

/// Slide 1: the music vault. Only the graphic follows the clock; the texts
/// and cards under it are built once instead of on every frame.
class _IdentitySlide extends StatelessWidget {
  final ValueNotifier<double> timeNotifier;
  final Size size;
  final LocaleProvider locale;
  final AppStrings strings;
  final String selectedVinylMask;

  const _IdentitySlide({
    required this.timeNotifier,
    required this.size,
    required this.locale,
    required this.strings,
    required this.selectedVinylMask,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),

          ExcludeSemantics(
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: timeNotifier,
                builder: (context, t, _) => _MusicVaultGraphic(
                  size: size,
                  t: t,
                  locale: locale,
                  strings: strings,
                  selectedVinylMask: selectedVinylMask,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

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
              strings.onboardingSlide1Badge,
              style: locale.getTextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            strings.onboardingSlide1Title,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
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

          Text(
            strings.onboardingSlide1Desc,
            textAlign: TextAlign.center,
            style: locale.getTextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTechPill(
                null,
                strings.onboardingPillFavorites,
                locale,
                Image.asset(
                  'assets/images/tengu.png',
                  width: 12,
                  height: 12,
                  fit: BoxFit.contain,
                  color: AppColors.accent,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              _buildTechPill(
                Icons.cloud_done_rounded,
                strings.onboardingPillStorage,
                locale,
              ),
              _buildTechPill(
                Icons.album_rounded,
                strings.onboardingPillAlbums,
                locale,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Marking a song lights its Oni mask.
          _BeforeAfterCard(
            locale: locale,
            arrowGap: 16,
            before: _StateSample(
              locale: locale,
              color: AppColors.textMuted,
              label: strings.onboardingOniMaskNotListened,
              icon: Image.asset(
                'assets/images/tengu.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                color: AppColors.textMuted.withValues(alpha: 0.4),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            after: _StateSample(
              locale: locale,
              color: AppColors.accent,
              label: strings.onboardingOniMaskListened,
              icon: Image.asset(
                'assets/images/tengu.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                color: AppColors.accent,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            hint: strings.onboardingOniMaskHint,
          ),
          const SizedBox(height: 10),

          // Listening to every song of an album completes it.
          _BeforeAfterCard(
            locale: locale,
            arrowGap: 12,
            before: _StateSample(
              locale: locale,
              color: AppColors.textMuted,
              label: strings.onboardingAlbumProgress0,
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.bgMid,
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.album_rounded,
                  size: 22,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ),
            ),
            after: _StateSample(
              locale: locale,
              color: AppColors.accent,
              label: strings.onboardingAlbumProgress100,
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFF8B0000)],
                  ),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.album_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
            hint: strings.onboardingAlbumProgressHint,
            hintAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A card showing a state turning into another, with a hint under it.
class _BeforeAfterCard extends StatelessWidget {
  final LocaleProvider locale;
  final Widget before;
  final Widget after;
  final double arrowGap;
  final String hint;
  final TextAlign? hintAlign;

  const _BeforeAfterCard({
    required this.locale,
    required this.before,
    required this.after,
    required this.arrowGap,
    required this.hint,
    this.hintAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              before,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: arrowGap),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.accent.withValues(alpha: 0.6),
                ),
              ),
              after,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: hintAlign,
            style: locale.getTextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One side of a [_BeforeAfterCard]: an icon over a small label.
class _StateSample extends StatelessWidget {
  final LocaleProvider locale;
  final Widget icon;
  final String label;
  final Color color;

  const _StateSample({
    required this.locale,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          label,
          style: locale.getTextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// The floating vault card with a spinning vinyl and the favorites chip.
class _MusicVaultGraphic extends StatelessWidget {
  final Size size;
  final double t;
  final LocaleProvider locale;
  final AppStrings strings;
  final String selectedVinylMask;

  const _MusicVaultGraphic({
    required this.size,
    required this.t,
    required this.locale,
    required this.strings,
    required this.selectedVinylMask,
  });

  @override
  Widget build(BuildContext context) {
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
              Transform.translate(
                offset: const Offset(-18, 0),
                child: _buildVaultCard(),
              ),
              Transform.translate(
                offset: const Offset(36, 0),
                child: Transform.rotate(
                  angle: t * 1.2,
                  child: _buildVinyl(),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 28,
                child: _buildFavoritesChip(pulse),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaultCard() {
    return Container(
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
          Positioned(
            top: 14,
            left: 14,
            child: Row(
              children: [
                const CyberNavIcon(
                  tab: MainTab.library,
                  isSelected: true,
                  size: 16,
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
    );
  }

  Widget _buildVinyl() {
    return Container(
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF2B40),
                  Color(0xFF7A000D),
                ],
              ),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                selectedVinylMask,
                width: 25,
                height: 25,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesChip(double pulse) {
    return Container(
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
          Image.asset(
            'assets/images/tengu.png',
            width: 13,
            height: 13,
            fit: BoxFit.contain,
            color: AppColors.accent,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 5),
          Text(
            strings.tabFavorites.toUpperCase(),
            style: locale.getTextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
