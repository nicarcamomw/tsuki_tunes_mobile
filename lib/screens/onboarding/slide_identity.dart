part of 'onboarding_screen.dart';

Widget _buildSlide1Identity(
    Size size, double t, LocaleProvider locale, AppStrings strings, String selectedVinylMask) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        const SizedBox(height: 12),

        ExcludeSemantics(child: _buildMusicVaultGraphic(size, t, locale, strings, selectedVinylMask)),

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

        Container(
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
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/tengu.png',
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.onboardingOniMaskNotListened,
                        style: locale.getTextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                  ),
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/tengu.png',
                        width: 26,
                        height: 26,
                        fit: BoxFit.contain,
                        color: AppColors.accent,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.onboardingOniMaskListened,
                        style: locale.getTextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.onboardingOniMaskHint,
                style: locale.getTextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Container(
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
                  Column(
                    children: [
                      Container(
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
                      const SizedBox(height: 4),
                      Text(
                        strings.onboardingAlbumProgress0,
                        style: locale.getTextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
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
                      const SizedBox(height: 4),
                      Text(
                        strings.onboardingAlbumProgress100,
                        style: locale.getTextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                strings.onboardingAlbumProgressHint,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Widget _buildMusicVaultGraphic(
    Size size, double t, LocaleProvider locale, AppStrings strings, String selectedVinylMask) {
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
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Row(
                        children: [
                          const CyberNavIcon(
                            index: 2,
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
              ),
            ),

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
                ),
              ),
            ),

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
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
