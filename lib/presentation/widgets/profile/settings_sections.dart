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
              HapticFeedback.selectionClick();
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
          HapticFeedback.selectionClick();
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
          HapticFeedback.selectionClick();
          audio.setNormalizeVolume(v);
          setState(() {});
        },
      ),
      _SettingSwitch(
        locale: locale,
        icon: Icons.vibration_rounded,
        title: strings.shakeSkipTitle,
        subtitle: strings.shakeSkipSubtitle,
        value: shakeSkip.enabled,
        onChanged: (v) {
          HapticFeedback.selectionClick();
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
          HapticFeedback.selectionClick();
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
                fontSize: 9,
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
                    audio.setCrossfadeSeconds(sec);
                    setState(() {});
                  },
                ),
              ),
            ),
            Text(
              '12s',
              style: locale.getTextStyle(
                fontSize: 9,
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
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            locale.strings.crossfadeSecondsLabel(audio.crossfadeSeconds),
            style: locale.getTextStyle(
              fontSize: 10,
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
          HapticFeedback.selectionClick();
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
          HapticFeedback.selectionClick();
          audio.setAutoplaySimilar(v);
          setState(() {});
        },
      ),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textBright,
          ),
        ),
        subtitle: Text(
          strings.smartShuffleSubtitle,
          style: locale.getTextStyle(
              fontSize: 10, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textMuted, size: 18),
        onTap: () {
          HapticFeedback.selectionClick();
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
          HapticFeedback.lightImpact();
          Clipboard.setData(ClipboardData(text: PlaybackLog.instance.dump()));
          ScaffoldMessenger.of(widget.hostContext).showSnackBar(
            SnackBar(content: Text(strings.playbackLogCopied)),
          );
        },
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.delete_sweep_rounded,
        iconColor: AppColors.textSecondary,
        iconSemanticLabel: strings.a11yClearCache,
        label: strings.clearAudioCache,
        labelColor: AppColors.textSecondary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        onTap: () {
          HapticFeedback.lightImpact();
          AudioPrecacheService().clearCache();
          ScaffoldMessenger.of(widget.hostContext).showSnackBar(
            SnackBar(content: Text(strings.audioCacheCleared)),
          );
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
          HapticFeedback.selectionClick();
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
          unawaited(HapticFeedback.selectionClick());
          if (!v) {
            await weather.disable();
            if (mounted) setState(() {});
            return;
          }
          // Turning it on starts with choosing where.
          await widget.closeThen(() => WeatherSheet.show(host));
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
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            locale.currentLanguage.tag,
            style: locale.getTextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
        onTap: () => widget.closeThen(() async {
          LanguageSelectorSheet.show(host);
        }),
      ),
      _SettingLink(
        locale: locale,
        icon: Icons.auto_stories_rounded,
        iconColor: AppColors.neonCyan,
        label: strings.tutorialOption,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        onTap: () => widget.closeThen(() async {
          unawaited(const TutorialRoute().push(host));
        }),
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
    final b = await StorageService().getBirthday();
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
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final mmdd = '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      await StorageService().saveBirthday(mmdd);
      if (mounted) {
        setState(() => _birthday = mmdd);
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _pickDate,
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
                  fontSize: 12,
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
                  fontSize: 11,
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
