import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/battery_family.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';

/// Step by step, for this phone's maker, how to stop it from freezing
/// Spotify in the background, with a shortcut to Spotify's settings.
class BatteryGuideSheet extends ConsumerWidget {
  final BatteryFamily family;
  final String makerName;
  final ScrollController controller;

  const BatteryGuideSheet({
    super.key,
    required this.family,
    required this.makerName,
    required this.controller,
  });

  static Future<void> show(BuildContext context) {
    final guide = context.readState(batteryGuideProvider);
    final family = guide.family;
    if (family == null) return Future.value();
    return SwipeableSheet.show(
      context,
      initialChildSize: 0.7,
      builder: (ctx, controller) => BatteryGuideSheet(
        family: family,
        makerName: guide.makerName,
        controller: controller,
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    Haptics.tap();
    final messenger = ScaffoldMessenger.of(context);
    final failedText = context.readState(stringsProvider).batteryGuideOpenFailed;
    final opened = await context.readState(batteryGuideProvider).openSpotifySettings();
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final steps = [
      strings.batteryGuideStepOpen,
      strings.batteryGuideStepBattery(family),
      strings.batteryGuideStepAutostart(family),
      strings.batteryGuideStepRetry,
    ];

    return SafeArea(
      top: false,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.borderGlow,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.battery_alert_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.batteryGuideTitle,
                  style: locale.getTextStyle(
                    fontSize: AppFontSize.titleLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBright,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.batteryGuideIntro(makerName),
            style: locale.getTextStyle(
              fontSize: AppFontSize.bodyLg,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.bodyLg,
                        color: AppColors.textBright,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: Text(
                strings.batteryGuideOpenSettings,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentFill,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () { Haptics.tap();
              context.readState(batteryGuideProvider).dismiss();
              Navigator.of(context).pop();
            },
            child: Text(
              strings.batteryGuideDontShow,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
