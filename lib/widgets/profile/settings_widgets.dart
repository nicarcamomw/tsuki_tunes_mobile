part of '../profile_bottom_sheet.dart';

class _SectionHeader extends StatelessWidget {
  final LocaleProvider locale;
  final String title;

  const _SectionHeader({required this.locale, required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: locale.getTextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// The rounded box a settings section's rows sit in, divided by thin lines.
class _SettingsCard extends StatelessWidget {
  final List<Widget> rows;

  const _SettingsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final LocaleProvider locale;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.locale,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      activeThumbColor: AppColors.accent,
      secondary: Icon(icon,
          size: 18, color: value ? AppColors.accent : AppColors.textMuted),
      title: Text(
        title,
        style: locale.getTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textBright,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
    );
  }
}

/// A tappable settings row: icon, label, optional [trailing] and a chevron.
class _SettingLink extends StatelessWidget {
  final LocaleProvider locale;
  final IconData icon;
  final Color iconColor;
  final String? iconSemanticLabel;
  final String label;
  final Color labelColor;
  final Widget? trailing;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _SettingLink({
    required this.locale,
    required this.icon,
    required this.iconColor,
    this.iconSemanticLabel,
    required this.label,
    this.labelColor = AppColors.textBright,
    this.trailing,
    this.borderRadius = BorderRadius.zero,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18, semanticLabel: iconSemanticLabel),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
