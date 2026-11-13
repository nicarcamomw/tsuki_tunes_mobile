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
            fontSize: AppFontSize.micro,
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
        borderRadius: BorderRadius.circular(AppRadius.card),
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
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w700,
          color: AppColors.textBright,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
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
                  fontSize: AppFontSize.body,
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

/// Which build is installed, at the bottom of the settings: the version,
/// and the CI build and commit it came from (the build matches the APK's
/// name, tsuki-tunes-N.apk); local builds say debug. A tap copies it, for a
/// bug report.
class _AppVersionLabel extends StatelessWidget {
  final LocaleProvider locale;
  final BuildContext hostContext;

  const _AppVersionLabel({required this.locale, required this.hostContext});

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  // Set by the CI build (.github/workflows/build-apk.yml).
  static const _build = String.fromEnvironment('BUILD_NUMBER');
  static const _commit = String.fromEnvironment('GIT_SHA');

  static String _describe(PackageInfo info) => [
        'Tsuki Tunes ${info.version}',
        if (_build.isNotEmpty) 'build $_build',
        if (_commit.isNotEmpty)
          _commit.length > 7 ? _commit.substring(0, 7) : _commit,
        if (!kReleaseMode) 'debug',
        if (useFirebaseEmulators) 'emulators',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox(height: 16);
        final text = _describe(info);
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: () {
            Haptics.tap();
            Clipboard.setData(ClipboardData(text: text));
            AppSnack.of(context).info(locale.strings.appVersionCopied);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
            ),
          ),
        );
      },
    );
  }
}
