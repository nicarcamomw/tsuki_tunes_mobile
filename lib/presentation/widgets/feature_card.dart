import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/locale_provider.dart';
import 'glass_card.dart';

/// A small tinted card that opens a feature: icon, name and a line of state.
class FeatureCard extends StatelessWidget {
  final LocaleProvider locale;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.locale,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: GlassCard(
          color: color,
          highlightAlpha: highlight ? 0.18 : 0.08,
          dimAlpha: highlight ? 0.08 : 0.03,
          borderAlpha: highlight ? 0.6 : 0.3,
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.micro, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
