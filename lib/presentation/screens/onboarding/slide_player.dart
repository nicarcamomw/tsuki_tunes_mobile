part of 'onboarding_screen.dart';

Widget _buildSlide3Player(Size size, double t, LocaleProvider locale, AppStrings strings) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        const SizedBox(height: 12),

        ExcludeSemantics(child: _buildPlayerMockupGraphic(size, t)),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            strings.onboardingSlide3Badge,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          strings.onboardingSlide3Title,
          textAlign: TextAlign.center,
          style: locale.getTextStyle(
            fontSize: AppFontSize.headline,
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
          strings.onboardingSlide3Desc,
          textAlign: TextAlign.center,
          style: locale.getTextStyle(
            fontSize: AppFontSize.bodyLg,
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
            _buildTechPill(Icons.equalizer_rounded, strings.onboardingPillEqualizer, locale),
            _buildTechPill(Icons.fullscreen_rounded, strings.onboardingPillFullscreen, locale),
            _buildTechPill(Icons.speed_rounded, strings.onboardingPillCyberHUD, locale),
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
            borderRadius: BorderRadius.circular(AppRadius.sheet),
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
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.accent,
                          i % 2 == 0
                              ? const Color(0xFFFF2B40)
                              : AppColors.neonCyan,
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
                            fontSize: AppFontSize.caption,
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
                            fontSize: AppFontSize.micro,
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
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.neonCyan, AppColors.accent],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
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
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '03:44',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

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
