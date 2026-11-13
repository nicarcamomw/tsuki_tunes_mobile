part of '../home_screen.dart';

void _showAffinityInfo(BuildContext context, LocaleProvider locale) {
  final strings = locale.strings;
  showModalBottomSheet(
    context: context,
    // Above the mini player and the nav bar, so neither covers the end.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.affinityInfoTitle,
            style: locale.getTextStyle(
              fontSize: AppFontSize.heading,
              fontWeight: FontWeight.w800,
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '親和性 // AFFINITY.SCORE',
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.accent.withValues(alpha: 0.85),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.affinityInfoIntro,
            style: locale.getTextStyle(
              fontSize: AppFontSize.bodyLg,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _AffinityFactor(
            icon: Icons.headphones,
            color: AppColors.accent,
            title: strings.affinitySavedTitle,
            body: strings.affinitySavedBody,
            points: strings.affinityPoints(2),
            locale: locale,
          ),
          const SizedBox(height: 10),
          _AffinityFactor(
            icon: Icons.person_search,
            color: AppColors.neonCyan,
            title: strings.affinityVisitsTitle,
            body: strings.affinityVisitsBody,
            points: strings.affinityPoints(1),
            locale: locale,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgDeep,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.functions, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Text(
                  '${strings.affinityFormulaLabel}  ',
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.micro,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 1.4,
                  ),
                ),
                Expanded(
                  child: Text(
                    strings.affinityFormula,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.bodyLg,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up,
                  size: 16, color: AppColors.textMuted.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.affinityInfoOutro,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentText,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                strings.affinityInfoClose,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
  );
}

/// One way to earn affinity, in the affinity info sheet.
class _AffinityFactor extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String points;
  final LocaleProvider locale;

  const _AffinityFactor({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.points,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.bodyLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.body,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              points,
              style: locale.getTextStyle(
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
