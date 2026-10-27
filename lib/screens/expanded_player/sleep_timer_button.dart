import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/audio_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/tap_scale.dart';

class PlayerSleepTimerButton extends StatelessWidget {
  const PlayerSleepTimerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final audio = context.read<AudioProvider>();
    final isActive = context.select<AudioProvider, bool>((a) => a.isSleepTimerActive);
    final remaining = context.select<AudioProvider, Duration?>((a) => a.sleepTimerRemaining);

    String label = '';
    if (remaining != null) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      label = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return TapScale(
      semanticLabel: strings.sleepTimer,
      onTap: () => _showSleepTimerSheet(context, audio, locale),
      scaleDown: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: AppColors.accent.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 16,
              color: isActive ? AppColors.accent : AppColors.textMuted,
              semanticLabel: strings.a11ySleepTimer,
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ] else if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                strings.sleepTimerEndOfTrackShort,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, AudioProvider audio, LocaleProvider locale) {
    final strings = locale.strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.bedtime_outlined, color: AppColors.accent, size: 18, semanticLabel: strings.a11ySleepTimer),
                    const SizedBox(width: 8),
                    Text(
                      strings.sleepTimer,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SleepTimerOption(
                  label: strings.sleepTimerOff,
                  isSelected: !audio.isSleepTimerActive,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(null); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerOff, TextDirection.ltr); Navigator.pop(context); },
                ),
                _SleepTimerOption(
                  label: strings.sleepTimerEndOfTrack,
                  isSelected: audio.isSleepTimerActive && audio.sleepTimerRemaining == null,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(Duration.zero); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerEndOfTrack, TextDirection.ltr); Navigator.pop(context); },
                ),
                _SleepTimerOption(
                  label: strings.sleepTimerMinutes(15),
                  isSelected: audio.sleepTimerOriginalMinutes == 15,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(const Duration(minutes: 15)); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerMinutes(15), TextDirection.ltr); Navigator.pop(context); },
                ),
                _SleepTimerOption(
                  label: strings.sleepTimerMinutes(30),
                  isSelected: audio.sleepTimerOriginalMinutes == 30,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(const Duration(minutes: 30)); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerMinutes(30), TextDirection.ltr); Navigator.pop(context); },
                ),
                _SleepTimerOption(
                  label: strings.sleepTimerMinutes(45),
                  isSelected: audio.sleepTimerOriginalMinutes == 45,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(const Duration(minutes: 45)); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerMinutes(45), TextDirection.ltr); Navigator.pop(context); },
                ),
                _SleepTimerOption(
                  label: strings.sleepTimerMinutes(60),
                  isSelected: audio.sleepTimerOriginalMinutes == 60,
                  locale: locale,
                  onTap: () { audio.setSleepTimer(const Duration(minutes: 60)); SemanticsService.sendAnnouncement(View.of(context), strings.sleepTimerMinutes(60), TextDirection.ltr); Navigator.pop(context); },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SleepTimerOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final LocaleProvider locale;
  final VoidCallback onTap;

  const _SleepTimerOption({
    required this.label,
    required this.isSelected,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: locale.getTextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.accent, size: 18, semanticLabel: locale.strings.a11ySelected),
            ],
          ),
        ),
      ),
    );
  }
}
