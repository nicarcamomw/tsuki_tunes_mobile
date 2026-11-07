import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/ambient_provider.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import 'eco_widgets.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';

class AmbientMixerSheet extends ConsumerStatefulWidget {
  const AmbientMixerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return SwipeableSheet.show(
      context,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, controller) => const AmbientMixerSheet(),
    );
  }

  static IconData iconFor(AmbientSound sound) => switch (sound) {
        AmbientSound.rain => Icons.water_drop_rounded,
        AmbientSound.storm => Icons.thunderstorm_rounded,
        AmbientSound.waves => Icons.waves_rounded,
        AmbientSound.fire => Icons.local_fire_department_rounded,
        AmbientSound.wind => Icons.air_rounded,
        AmbientSound.night => Icons.nightlight_round,
        AmbientSound.brownNoise => Icons.graphic_eq_rounded,
      };

  @override
  ConsumerState<AmbientMixerSheet> createState() => _AmbientMixerSheetState();
}

class _AmbientMixerSheetState extends ConsumerState<AmbientMixerSheet> {
  static const _color = AppColors.neonCyan;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refreshes the "stops in" countdown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(ambientProvider).stopRemaining != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ambient = ref.watch(ambientProvider);
    final level = ref.watch(maskProvider.select((m) => m.level));
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final remaining = ambient.stopRemaining;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderGlow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.spa_rounded, color: _color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    strings.ambientTitle,
                    style: locale.getTextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _color,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.ambientSubtitle,
              style: locale.getTextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: [
                for (final sound in AmbientSound.values)
                  _SoundTile(
                    icon: AmbientMixerSheet.iconFor(sound),
                    label: strings.ambientName(sound),
                    active: ambient.isOn(sound),
                    loading: ambient.isLoading(sound),
                    // Each sound opens at its Eco level.
                    lockedAt: EcoLevels.soundOpen(sound, level) ? null : EcoLevels.soundLevels[sound],
                    onTap: () {
                      Haptics.selection();
                      if (!EcoLevels.soundOpen(sound, level)) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.bgCard,
                            content: Text('${strings.ambientName(sound)} · ${strings.ecoOpensAt(EcoLevels.soundLevels[sound]!)}'),
                          ));
                        return;
                      }
                      ambient.toggle(sound);
                    },
                    locale: locale,
                  ),
              ],
            ),

            if (ambient.isActive) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgMid,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Column(
                  children: [
                    for (final sound in AmbientSound.values)
                      if (ambient.isOn(sound))
                        Row(
                          children: [
                            Icon(AmbientMixerSheet.iconFor(sound), size: 16, color: _color),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 78,
                              child: Text(
                                strings.ambientName(sound),
                                overflow: TextOverflow.ellipsis,
                                style: locale.getTextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textBright,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: _color,
                                  inactiveTrackColor: AppColors.border,
                                  thumbColor: _color,
                                  overlayColor: _color.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: ambient.volumeOf(sound),
                                  onChanged: (v) => ambient.setVolume(sound, v),
                                  onChangeEnd: (_) => ambient.commitVolumes(),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Haptics.tap();
                        ambient.isPlaying ? ambient.pauseAll() : ambient.resumeAll();
                      },
                      icon: Icon(
                        ambient.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: _color,
                        size: 18,
                      ),
                      label: Text(
                        ambient.isPlaying ? strings.ambientPause : strings.ambientResume,
                        style: locale.getTextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _color,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _color.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Haptics.remove();
                        ambient.stopAll();
                      },
                      icon: const Icon(Icons.stop_rounded, color: AppColors.textSecondary, size: 18),
                      label: Text(
                        strings.ambientStopAll,
                        style: locale.getTextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.bedtime_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    strings.ambientAfterTimerTitle,
                    style: locale.getTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in AmbientProvider.afterTimerOptions)
                  ChoiceChip(
                    label: Text(strings.ambientAfterTimerOption(m)),
                    selected: ambient.afterTimerMinutes == m,
                    onSelected: (_) {
                      Haptics.selection();
                      ambient.setAfterTimerMinutes(m);
                    },
                    showCheckmark: false,
                    labelStyle: locale.getTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ambient.afterTimerMinutes == m ? AppColors.bgDeep : AppColors.textPrimary,
                    ),
                    selectedColor: _color,
                    backgroundColor: AppColors.bgMid,
                    side: BorderSide(
                      color: ambient.afterTimerMinutes == m ? _color : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
              ],
            ),
            if (remaining != null) ...[
              const SizedBox(height: 10),
              Text(
                strings.ambientStopsIn(_fmt(remaining)),
                style: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              strings.ambientHint,
              style: locale.getTextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final VoidCallback onTap;
  final LocaleProvider locale;

  /// The Eco level this sound opens at, while it's still closed.
  final int? lockedAt;

  const _SoundTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.loading,
    required this.onTap,
    required this.locale,
    this.lockedAt,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.neonCyan;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : AppColors.bgMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.8) : AppColors.border,
            ),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 26,
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: color),
                        ),
                      )
                    : Icon(lockedAt == null ? icon : Icons.lock_outline_rounded,
                        size: 24, color: active ? color : AppColors.textMuted.withValues(alpha: lockedAt == null ? 1 : 0.6)),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  lockedAt == null ? label : '$label · ${locale.strings.ecoLevelShort(lockedAt!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.textBright : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
