import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_strings.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/locale_provider.dart';
import '../services/song_radio.dart';

/// Starts a song radio and tells the user how it went.
Future<void> startRadioWithFeedback(
  BuildContext context,
  Track track, {
  double bottomMargin = 12,
}) async {
  HapticFeedback.mediumImpact();
  final audio = context.read<AudioProvider>();
  final locale = context.read<LocaleProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await audio.startRadio(track);
  _snack(
    messenger,
    locale,
    ok ? locale.strings.radioStarted(track.title) : locale.strings.radioNoResults,
    bottomMargin: bottomMargin,
    icon: ok ? Icons.sensors : Icons.sensors_off,
  );
}

Future<void> showRadioControlSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _RadioControlSheet(),
  );
}

/// Human-readable "why is this song here" for queue rows.
String? radioReasonLabel(AppStrings strings, RadioReason? reason) {
  if (reason == null) return null;
  return switch (reason.source) {
    RadioSource.seed => null,
    RadioSource.lastfm => '${strings.radioReasonLastFm(reason.seedTitle)} · LAST.FM',
    RadioSource.deezer => '${strings.radioReasonDeezer(reason.seedArtist)} · DEEZER',
  };
}

String radioStatusLabel(AppStrings strings, RadioStatus status) =>
    switch (status) {
      RadioStatus.loading => strings.radioLoadingMore,
      RadioStatus.ready => strings.radioInfinite,
      RadioStatus.offline => strings.radioOffline,
      RadioStatus.exhausted => strings.radioExhausted,
    };

void _snack(
  ScaffoldMessengerState messenger,
  LocaleProvider locale,
  String text, {
  double bottomMargin = 12,
  IconData icon = Icons.sensors,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      margin: EdgeInsets.only(bottom: bottomMargin, left: 16, right: 16),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
          ),
        ],
      ),
    ));
}

class _RadioControlSheet extends StatelessWidget {
  const _RadioControlSheet();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final seed = audio.radioSeed;
    final current = audio.currentTrack;

    if (seed == null) {
      // Radio ended while the sheet was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox(height: 120);
    }

    final status = audio.radioStatus;
    final mode = audio.radioMode;
    final modeDesc = switch (mode) {
      RadioMode.familiar => strings.radioModeFamiliarDesc,
      RadioMode.balanced => strings.radioModeBalancedDesc,
      RadioMode.adventurous => strings.radioModeAdventurousDesc,
    };
    final messenger = ScaffoldMessenger.of(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(
                    dimension: 56,
                    child: seed.coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: seed.coverUrl, fit: BoxFit.cover)
                        : Container(color: AppColors.bgMid),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.all_inclusive,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            strings.radioLabel,
                            style: locale.getTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.radioBasedOn(seed.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBright,
                        ),
                      ),
                      Text(
                        seed.fullArtistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatusLine(status: status, locale: locale),
            const SizedBox(height: 4),
            Text(
              audio.radioUsesLastFm
                  ? strings.radioSourcesBoth
                  : strings.radioSourcesDeezerOnly,
              style: locale.getTextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.radioModeTitle,
              style: locale.getTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RadioMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: RadioMode.familiar,
                  icon: const Icon(Icons.adjust, size: 16),
                  label: Text(strings.radioModeFamiliar),
                ),
                ButtonSegment(
                  value: RadioMode.balanced,
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(strings.radioModeBalanced),
                ),
                ButtonSegment(
                  value: RadioMode.adventurous,
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: Text(strings.radioModeAdventurous),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                audio.setRadioMode(s.first);
              },
              style: SegmentedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                selectedForegroundColor: AppColors.textBright,
                selectedBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.25),
                side: const BorderSide(color: AppColors.border),
                textStyle: locale.getTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              modeDesc,
              style: locale.getTextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (current != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SteerButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: strings.radioMoreLikeThis,
                      color: AppColors.neonCyan,
                      locale: locale,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                        audio.radioMoreLikeThis();
                        _snack(messenger, locale, strings.radioMoreSnack,
                            bottomMargin: bottomPad + 12,
                            icon: Icons.thumb_up_alt_outlined);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SteerButton(
                      icon: Icons.thumb_down_alt_outlined,
                      label: strings.radioLessLikeThis,
                      color: AppColors.sakura,
                      locale: locale,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final artist = SongRadio.primaryArtist(current);
                        Navigator.of(context).pop();
                        audio.radioLessLikeThis();
                        _snack(messenger, locale, strings.radioLessSnack(artist),
                            bottomMargin: bottomPad + 12,
                            icon: Icons.thumb_down_alt_outlined);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              strings.radioLearnHint,
              style: locale.getTextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  audio.stopRadio();
                  _snack(messenger, locale, strings.radioStopped,
                      bottomMargin: bottomPad + 12, icon: Icons.sensors_off);
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(strings.radioStop),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final RadioStatus status;
  final LocaleProvider locale;
  const _StatusLine({required this.status, required this.locale});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RadioStatus.loading || RadioStatus.ready => AppColors.neonCyan,
      RadioStatus.offline || RadioStatus.exhausted => AppColors.warning,
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (status == RadioStatus.loading)
            const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.neonCyan),
            )
          else
            Icon(
              status == RadioStatus.ready
                  ? Icons.all_inclusive
                  : Icons.info_outline,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              radioStatusLabel(locale.strings, status),
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SteerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final LocaleProvider locale;
  final VoidCallback onTap;

  const _SteerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
