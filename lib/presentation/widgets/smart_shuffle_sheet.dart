import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import 'haptics.dart';
import 'shuffle_mode_icon.dart';
import 'swipeable_sheet.dart';

/// Smart shuffle settings: no same artist in a row, the energy (tempo)
/// flow and how many recommended songs to slip in.
Future<void> showSmartShuffleSheet(BuildContext context) {
  return SwipeableSheet.show(
    context,
    initialChildSize: 0.7,
    maxChildSize: 0.92,
    builder: (_, controller) => _SmartShuffleSheet(controller: controller),
  );
}

/// How often a recommended song comes: one every this many of yours.
const _recoChoices = [5, 3, 2];

class _SmartShuffleSheet extends ConsumerWidget {
  final ScrollController controller;

  const _SmartShuffleSheet({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final mode = audio.shuffleMode;
    final energy = audio.shuffleEnergy;
    final every = _recoChoices.contains(audio.recommendEvery)
        ? audio.recommendEvery
        : 3;

    TextStyle label() => locale.getTextStyle(
          fontSize: AppFontSize.micro,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.6,
        );
    TextStyle hint() => locale.getTextStyle(
          fontSize: AppFontSize.caption,
          color: AppColors.textSecondary,
          height: 1.35,
        );
    final segmentStyle = SegmentedButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      selectedForegroundColor: AppColors.textBright,
      selectedBackgroundColor: AppColors.accent.withValues(alpha: 0.25),
      side: const BorderSide(color: AppColors.border),
      textStyle: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700),
    );

    return SafeArea(
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const ShuffleModeIcon(
                  mode: ShuffleMode.smart, color: AppColors.accent, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.smartShuffleTitle,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.titleLg,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBright,
                      ),
                    ),
                    Text(strings.smartShuffleSubtitle, style: hint()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Shuffle on/off and recommendations, the button's three states.
          SegmentedButton<ShuffleMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ShuffleMode.off,
                label: Text(strings.shuffleOffToast),
              ),
              ButtonSegment(
                value: ShuffleMode.on,
                icon: const Icon(Icons.shuffle, size: 16),
                label: Text(strings.shuffle),
              ),
              ButtonSegment(
                value: ShuffleMode.smart,
                icon: const SparkleIcon(color: AppColors.accent, size: 14),
                label: Text(strings.shuffleRecoTitle),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) {
              Haptics.selection();
              audio.setShuffleMode(s.first);
            },
            style: segmentStyle,
          ),
          const SizedBox(height: 22),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: audio.avoidSameArtist,
            activeThumbColor: AppColors.accent,
            onChanged: (v) {
              Haptics.selection();
              audio.setAvoidSameArtist(v);
            },
            title: Text(
              strings.shuffleAvoidArtistTitle,
              style: locale.getTextStyle(
                fontSize: AppFontSize.bodyLg,
                fontWeight: FontWeight.w700,
                color: AppColors.textBright,
              ),
            ),
            subtitle: Text(strings.shuffleAvoidArtistSubtitle, style: hint()),
          ),
          const SizedBox(height: 14),

          Text(strings.shuffleEnergyTitle.toUpperCase(), style: label()),
          const SizedBox(height: 8),
          SegmentedButton<ShuffleEnergy>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ShuffleEnergy.free,
                icon: const Icon(Icons.casino_outlined, size: 16),
                label: Text(strings.shuffleEnergyFree),
              ),
              ButtonSegment(
                value: ShuffleEnergy.alternate,
                icon: const Icon(Icons.swap_vert, size: 16),
                label: Text(strings.shuffleEnergyAlternate),
              ),
              ButtonSegment(
                value: ShuffleEnergy.smooth,
                icon: const Icon(Icons.trending_flat, size: 16),
                label: Text(strings.shuffleEnergySmooth),
              ),
            ],
            selected: {energy},
            onSelectionChanged: (s) {
              Haptics.selection();
              audio.setShuffleEnergy(s.first);
            },
            style: segmentStyle,
          ),
          const SizedBox(height: 8),
          Text(
            switch (energy) {
              ShuffleEnergy.free => strings.shuffleEnergyFreeHint,
              ShuffleEnergy.alternate => strings.shuffleEnergyAlternateHint,
              ShuffleEnergy.smooth => strings.shuffleEnergySmoothHint,
            },
            style: hint(),
          ),
          const SizedBox(height: 22),

          Text(strings.shuffleRecoTitle.toUpperCase(), style: label()),
          const SizedBox(height: 4),
          Text(strings.shuffleRecoSubtitle, style: hint()),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: mode == ShuffleMode.smart,
            activeThumbColor: AppColors.accent,
            onChanged: (v) {
              Haptics.selection();
              audio.setShuffleMode(v ? ShuffleMode.smart : ShuffleMode.on);
            },
            secondary: const SparkleIcon(color: AppColors.accent, size: 20),
            title: Text(
              strings.shuffleRecoSwitch,
              style: locale.getTextStyle(
                fontSize: AppFontSize.bodyLg,
                fontWeight: FontWeight.w700,
                color: AppColors.textBright,
              ),
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 5, label: Text(strings.shuffleRecoFew)),
              ButtonSegment(value: 3, label: Text(strings.shuffleRecoNormal)),
              ButtonSegment(value: 2, label: Text(strings.shuffleRecoMany)),
            ],
            selected: {every},
            onSelectionChanged: (s) {
              Haptics.selection();
              audio.setRecommendEvery(s.first);
            },
            style: segmentStyle,
          ),
          const SizedBox(height: 8),
          Text(strings.shuffleRecoEvery(every), style: hint()),
          const SizedBox(height: 18),
          Text(
            strings.shuffleHoldHint,
            style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
