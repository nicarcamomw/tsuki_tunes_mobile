part of 'onboarding_screen.dart';

Widget _buildSlide2Search(Size size, double t, LocaleProvider locale, AppStrings strings) {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    physics: const BouncingScrollPhysics(),
    child: Column(
      children: [
        const SizedBox(height: 12),

        ExcludeSemantics(child: _buildSearchCatalogGraphic(size, t)),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Text(
            strings.onboardingSlide2Badge,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w800,
              color: AppColors.neonCyan,
              letterSpacing: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          strings.onboardingSlide2Title,
          textAlign: TextAlign.center,
          style: locale.getTextStyle(
            fontSize: AppFontSize.headline,
            fontWeight: FontWeight.w900,
            color: AppColors.textBright,
            letterSpacing: 1.8,
            shadows: [
              BoxShadow(
                color: AppColors.neonCyan.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Text(
          strings.onboardingSlide2Desc,
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
            _buildTechPill(Icons.search_rounded, strings.onboardingPillSearch, locale),
            _buildTechPill(Icons.language_rounded, strings.onboardingPillTracks, locale),
            _buildTechPill(
                Icons.play_circle_filled_rounded, strings.onboardingPillPreview, locale),
          ],
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Widget _buildSearchCatalogGraphic(Size size, double t) {
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
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.neonCyan
                      .withValues(alpha: 0.20 + 0.08 * pulse),
                  AppColors.neonCyan.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),

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
                  color: AppColors.neonCyan.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withValues(alpha: 0.25),
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
                    color: AppColors.neonCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$activeQuery$blink',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppFontSize.body,
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
                      color: AppColors.neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'DEEZER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neonCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                          colors: [AppColors.accent, Color(0xFF8B0000)],
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
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textBright,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Daft Punk • Discovery',
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
                      Icons.play_circle_fill_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

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
                    color: AppColors.neonCyan.withValues(alpha: 0.45),
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
                          colors: [AppColors.neonCyan, Color(0xFF0055AA)],
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
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textBright,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'System of a Down • Toxicity',
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
                      Icons.play_circle_fill_rounded,
                      color: AppColors.neonCyan,
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
