part of '../profile_bottom_sheet.dart';

// Each section rebuilds itself after a change: the values live in providers
// the sheet only reads.

class _PlaybackSettings extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final LocaleProvider locale;

  const _PlaybackSettings({required this.hostContext, required this.locale});

  @override
  ConsumerState<_PlaybackSettings> createState() => _PlaybackSettingsState();
}

class _PlaybackSettingsState extends ConsumerState<_PlaybackSettings> {
  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final audio = ref.read(audioProvider);
    final shakeSkip = ref.read(shakeSkipProvider);
    final run = ref.read(runProvider);

    return _SettingsCard(rows: [
      Column(
        children: [
          _SettingSwitch(
            locale: locale,
            icon: Icons.graphic_eq_rounded,
            title: strings.crossfadeTitle,
            subtitle: audio.useSpotify
                ? strings.crossfadeSpotifySubtitle
                : strings.crossfadeSubtitle,
            value: audio.crossfadeSeconds > 0,
            onChanged: (v) {
              Haptics.selection();
              audio.setCrossfadeSeconds(v ? 3 : 0);
              setState(() {});
            },
          ),
          if (audio.crossfadeSeconds > 0) ..._buildCrossfadeSlider(context, audio),
        ],
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.task_alt_rounded,
        title: strings.autoMarkTitle,
        subtitle: strings.autoMarkSubtitle,
        value: audio.autoMarkListened,
        onChanged: (v) {
          Haptics.selection();
          audio.setAutoMarkListened(v);
          setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.equalizer_rounded,
        title: strings.normalizeTitle,
        subtitle: strings.normalizeSubtitle,
        value: audio.normalizeVolume,
        onChanged: (v) {
          Haptics.selection();
          audio.setNormalizeVolume(v);
          setState(() {});
        },
      ),
      ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: SizedBox(
          width: 24,
          child: Center(
            child: Icon(Icons.tune_rounded,
                size: 18, color: audio.eqPreset == EqPreset.off ? AppColors.textMuted : AppColors.accent),
          ),
        ),
        title: Text(
          strings.eqTitle,
          style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700, color: AppColors.textBright),
        ),
        subtitle: Text(
          strings.eqPresetName(audio.eqPreset),
          style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        onTap: () async {
          Haptics.tap();
          await showEqualizerSheet(widget.hostContext);
          if (mounted) setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.vibration_rounded,
        title: strings.shakeSkipTitle,
        subtitle: strings.shakeSkipSubtitle,
        value: shakeSkip.enabled,
        onChanged: (v) {
          Haptics.selection();
          shakeSkip.setEnabled(v);
          setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.directions_run_rounded,
        title: strings.runSettingTitle,
        subtitle: strings.runSettingSubtitle,
        value: run.enabled,
        onChanged: (v) {
          if (v && !ecoAllows(context, EcoFeature.running)) return;
          Haptics.selection();
          run.setEnabled(v);
          setState(() {});
        },
      ),
    ]);
  }

  List<Widget> _buildCrossfadeSlider(BuildContext context, AudioProvider audio) {
    final locale = widget.locale;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          children: [
            Text(
              '0s',
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
                color: AppColors.textMuted,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: audio.crossfadeSeconds.toDouble(),
                  min: 1,
                  max: 12,
                  divisions: 11,
                  onChanged: (val) {
                    final sec = val.round();
                    if (sec == audio.crossfadeSeconds) return;
                    // A tick per second, like a picker's detents.
                    Haptics.selection();
                    audio.setCrossfadeSeconds(sec);
                    setState(() {});
                  },
                ),
              ),
            ),
            Text(
              '12s',
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            audio.crossfadeSeconds == 0
                ? locale.strings.crossfadeGapless
                : locale.strings.crossfadeSecondsLabel(audio.crossfadeSeconds),
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    ];
  }
}

class _StorageSettings extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final LocaleProvider locale;

  const _StorageSettings({required this.hostContext, required this.locale});

  @override
  ConsumerState<_StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends ConsumerState<_StorageSettings> {
  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final audio = ref.read(audioProvider);

    return _SettingsCard(rows: [
      _SettingSwitch(
        locale: locale,
        icon: Icons.wifi_rounded,
        title: strings.precacheWifiTitle,
        subtitle: strings.precacheWifiSubtitle,
        value: audio.precacheWifiOnly,
        onChanged: (v) {
          Haptics.selection();
          audio.setPrecacheWifiOnly(v);
          setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.all_inclusive,
        title: strings.autoplaySimilarTitle,
        subtitle: strings.autoplaySimilarSubtitle,
        value: audio.autoplaySimilar,
        onChanged: (v) {
          Haptics.selection();
          audio.setAutoplaySimilar(v);
          setState(() {});
        },
      ),
      _ImageQualityRow(locale: locale, hostContext: widget.hostContext),
      ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const SizedBox(
          width: 24,
          child: Center(
            child: ShuffleModeIcon(
                mode: ShuffleMode.smart,
                color: AppColors.accent,
                size: 17),
          ),
        ),
        title: Text(
          strings.smartShuffleTitle,
          style: locale.getTextStyle(
            fontSize: AppFontSize.body,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        subtitle: Text(
          strings.smartShuffleSubtitle,
          style: locale.getTextStyle(
              fontSize: AppFontSize.micro, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textMuted, size: 18),
        onTap: () {
          if (!ecoAllows(context, EcoFeature.smartShuffle)) return;
          Haptics.tap();
          showSmartShuffleSheet(widget.hostContext);
        },
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.textSecondary,
        label: strings.playbackLogCopy,
        labelColor: AppColors.textSecondary,
        borderRadius: BorderRadius.zero,
        onTap: () {
          Haptics.tap();
          Clipboard.setData(ClipboardData(text: ref.read(playbackLogProvider).dump()));
          AppSnack.of(widget.hostContext).info(strings.playbackLogCopied);
        },
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.delete_sweep_rounded,
        iconColor: AppColors.textSecondary,
        iconSemanticLabel: strings.a11yClearCache,
        label: strings.clearAudioCache,
        labelColor: AppColors.textSecondary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
        onTap: () {
          Haptics.remove();
          ref.read(audioCacheProvider).clearCache();
          AppSnack.of(widget.hostContext).info(strings.audioCacheCleared);
        },
      ),
    ]);
  }
}

class _GeneralSettings extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final LocaleProvider locale;

  /// Closes the sheet, then runs the callback on the host.
  final Future<void> Function(Future<void> Function() then) closeThen;

  const _GeneralSettings({
    required this.hostContext,
    required this.locale,
    required this.closeThen,
  });

  @override
  ConsumerState<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends ConsumerState<_GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final host = widget.hostContext;
    final moon = ref.read(moonProvider);
    final weather = ref.read(weatherProvider);

    return _SettingsCard(rows: [
      _BirthdayRow(
        locale: locale,
        strings: strings,
        onChanged: () => setState(() {}),
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.nightlight_round,
        title: strings.moonAtmosphereTitle,
        subtitle: strings.moonAtmosphereSubtitle,
        value: moon.atmosphereEnabled,
        onChanged: (v) {
          Haptics.selection();
          moon.setAtmosphereEnabled(v);
          setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.cloud_rounded,
        title: strings.weatherSettingTitle,
        subtitle: strings.weatherSettingSubtitle,
        value: weather.enabled,
        onChanged: (v) async {
          Haptics.selection();
          if (!v) {
            await weather.disable();
            if (mounted) setState(() {});
            return;
          }
          // Turning it on starts with choosing where.
          await widget.closeThen(() => WeatherSheet.show(host));
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.vibration_rounded,
        title: strings.hapticsSettingTitle,
        subtitle: strings.hapticsSettingSubtitle,
        value: Haptics.enabled,
        onChanged: (v) async {
          await Haptics.setEnabled(v);
          // Turning it on answers with the feel it brings back.
          Haptics.selection();
          if (mounted) setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.insights_rounded,
        title: strings.analyticsSettingTitle,
        subtitle: strings.analyticsSettingSubtitle,
        value: ref.read(analyticsProvider).enabled,
        onChanged: (v) async {
          Haptics.selection();
          await ref.read(analyticsProvider).setEnabled(v);
          if (mounted) setState(() {});
        },
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.language_rounded,
        iconColor: AppColors.accent,
        label: strings.languageOption,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentDim,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            locale.currentLanguage.tag,
            style: locale.getTextStyle(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
        onTap: () => widget.closeThen(() async { Haptics.tap();
          LanguageSelectorSheet.show(host);
        }),
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.auto_stories_rounded,
        iconColor: AppColors.neonCyan,
        label: strings.tutorialOption,
        onTap: () => widget.closeThen(() async { Haptics.tap();
          unawaited(const TutorialRoute().push(host));
        }),
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.privacy_tip_outlined,
        iconColor: AppColors.textSecondary,
        label: strings.privacyPolicyOption,
        labelColor: AppColors.textSecondary,
        onTap: () { Haptics.tap(); _openLegalPage(privacyPolicyUrl); },
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.gavel_rounded,
        iconColor: AppColors.textSecondary,
        label: strings.termsOption,
        labelColor: AppColors.textSecondary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.card)),
        onTap: () { Haptics.tap(); _openLegalPage(termsOfServiceUrl); },
      ),
    ]);
  }
}

class _BirthdayRow extends StatefulWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  final VoidCallback onChanged;

  const _BirthdayRow({
    required this.locale,
    required this.strings,
    required this.onChanged,
  });

  @override
  State<_BirthdayRow> createState() => _BirthdayRowState();
}

class _BirthdayRowState extends State<_BirthdayRow> {
  String? _birthday;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await context.readState(storageProvider).getBirthday();
    if (mounted) setState(() { _birthday = b; _loaded = true; });
  }

  String _formatBirthday(String mmdd) {
    final parts = mmdd.split('-');
    if (parts.length != 2) return mmdd;
    final month = int.tryParse(parts[0]) ?? 1;
    final day = int.tryParse(parts[1]) ?? 1;
    final d = DateTime(2000, month, day);
    return widget.strings.shortDate(d);
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(2000, 6, 15);
    if (_birthday != null) {
      final parts = _birthday!.split('-');
      if (parts.length == 2) {
        initial = DateTime(
          2000,
          int.tryParse(parts[0]) ?? 6,
          int.tryParse(parts[1]) ?? 15,
        );
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2000, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.sakura,
            surface: AppColors.bgCard,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final mmdd = '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      if (!mounted) return;
      await context.readState(storageProvider).saveBirthday(mmdd);
      if (mounted) {
        setState(() => _birthday = mmdd);
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { Haptics.tap(); _pickDate(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.cake_rounded,
                color: _birthday != null ? AppColors.sakura : AppColors.textMuted,
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.strings.birthdayTitle,
                style: widget.locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright,
                ),
              ),
            ),
            if (_loaded)
              Text(
                _birthday != null
                    ? _formatBirthday(_birthday!)
                    : widget.strings.birthdayNotSet,
                style: widget.locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  color: _birthday != null ? AppColors.sakura : AppColors.textMuted,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> _openLegalPage(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    _log.warning('Could not open $url: $e');
  }
}


/// Settings > Storage: how big the large images are fetched.
class _ImageQualityRow extends ConsumerWidget {
  final LocaleProvider locale;
  final BuildContext hostContext;
  const _ImageQualityRow({required this.locale, required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = locale.strings;
    final quality = ref.watch(imageQualityProvider.select((s) => s.quality));
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const SizedBox(
        width: 24,
        child: Center(child: Icon(Icons.image_outlined, color: AppColors.accent, size: 18)),
      ),
      title: Text(
        strings.imageQualityTitle,
        style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700, color: AppColors.textBright),
      ),
      subtitle: Text(
        '${strings.imageQualityName(quality)} · ${strings.imageQualityDescription(quality)}',
        style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: () {
        Haptics.tap();
        unawaited(SwipeableSheet.show(
          hostContext,
          initialChildSize: 0.42,
          maxChildSize: 0.55,
          builder: (_, controller) => _ImageQualitySheet(locale: locale, controller: controller),
        ));
      },
    );
  }
}

class _ImageQualitySheet extends ConsumerWidget {
  final LocaleProvider locale;
  final ScrollController controller;
  const _ImageQualitySheet({required this.locale, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = locale.strings;
    final setting = ref.watch(imageQualityProvider);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(strings.imageQualityTitle,
              style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
        ),
        const SizedBox(height: 8),
        for (final q in [ImageQuality.dataSaver, ImageQuality.normal, ImageQuality.high])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            selected: setting.quality == q,
            title: Text(strings.imageQualityName(q),
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w700, color: AppColors.textBright)),
            subtitle: Text(strings.imageQualityDescription(q),
                style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)),
            trailing: setting.quality == q ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 20) : null,
            onTap: () {
              Haptics.selection();
              unawaited(setting.set(q));
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}
