import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/song_radio.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import 'app_snack.dart';
import 'eco_widgets.dart';
import 'haptics.dart';
import 'swipeable_sheet.dart';

/// Starts a song radio and tells the user how it went.
Future<void> startRadioWithFeedback(
  BuildContext context,
  Track track, {
  double? bottomMargin,
}) async {
  Haptics.confirm();
  final locale = context.readState(localeProvider);
  final snack = AppSnack.of(context, bottom: bottomMargin);
  final ok = await context.readState(startRadioProvider)(track);
  snack.info(
    ok ? locale.strings.radioStarted(track.title) : locale.strings.radioNoResults,
    icon: ok ? Icons.sensors : Icons.sensors_off,
    duration: const Duration(seconds: 3),
  );
}

/// Starts [artist]'s radio and tells the user how it went.
Future<void> startArtistRadioWithFeedback(
  BuildContext context,
  Artist artist, {
  double? bottomMargin,
}) async {
  if (!ecoAllows(context, EcoFeature.artistRadio)) return;
  Haptics.confirm();
  final locale = context.readState(localeProvider);
  final snack = AppSnack.of(context, bottom: bottomMargin);
  final ok = await context.readState(startArtistRadioProvider)(artist);
  snack.info(
    ok ? locale.strings.artistRadioStarted(artist.name) : locale.strings.radioNoResults,
    icon: ok ? Icons.sensors : Icons.sensors_off,
    duration: const Duration(seconds: 3),
  );
}

Future<void> showRadioControlSheet(BuildContext context) {
  return SwipeableSheet.show(
    context,
    initialChildSize: 0.55,
    maxChildSize: 0.85,
    builder: (_, controller) => const _RadioControlSheet(),
  );
}

/// Human-readable "why is this song here" for queue rows.
String? radioReasonLabel(AppStrings strings, RadioReason? reason) {
  if (reason == null) return null;
  return switch (reason.source) {
    RadioSource.seed => null,
    RadioSource.lastfm => '${strings.radioReasonLastFm(reason.seedTitle)} · LAST.FM',
    RadioSource.deezer => '${strings.radioReasonDeezer(reason.seedArtist)} · DEEZER',
    RadioSource.artistTop => strings.radioReasonArtistTop(reason.seedArtist),
    RadioSource.related => strings.radioReasonRelated(reason.seedArtist),
  };
}

String radioStatusLabel(AppStrings strings, RadioStatus status) =>
    switch (status) {
      RadioStatus.loading => strings.radioLoadingMore,
      RadioStatus.ready => strings.radioInfinite,
      RadioStatus.offline => strings.radioOffline,
      RadioStatus.exhausted => strings.radioExhausted,
    };

class _RadioControlSheet extends ConsumerWidget {
  const _RadioControlSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.read(audioProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final seed = ref.watch(audioProvider.select((a) => a.radioSeed));
    final radioArtist = ref.watch(audioProvider.select((a) => a.radioArtist));
    final current = ref.watch(currentTrackProvider);

    if (seed == null) {
      // Radio ended while the sheet was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox(height: 120);
    }

    final status = ref.watch(audioProvider.select((a) => a.radioStatus));
    final mode = ref.watch(audioProvider.select((a) => a.radioMode));
    final usesLastFm = ref.watch(audioProvider.select((a) => a.radioUsesLastFm));
    final modeDesc = switch (mode) {
      RadioMode.familiar => strings.radioModeFamiliarDesc,
      RadioMode.balanced => strings.radioModeBalancedDesc,
      RadioMode.adventurous => strings.radioModeAdventurousDesc,
    };
    final messenger = AppSnack.of(context, bottom: MediaQuery.paddingOf(context).bottom + 12);

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
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: SizedBox.square(
                    dimension: 56,
                    child: (radioArtist?.pictureUrl ?? seed.coverUrl).isNotEmpty
                        ? CachedNetworkImage(
                            memCacheWidth: imageCacheSize(context, 56),
                            imageUrl: radioArtist?.pictureUrl ?? seed.coverUrl, fit: BoxFit.cover)
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
                              fontSize: AppFontSize.micro,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        radioArtist != null ? strings.artistRadioOf(radioArtist.name) : strings.radioBasedOn(seed.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.titleLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBright,
                        ),
                      ),
                      if (radioArtist == null) Text(
                        seed.fullArtistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.body,
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
              usesLastFm
                  ? strings.radioSourcesBoth
                  : strings.radioSourcesDeezerOnly,
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.radioModeTitle,
              style: locale.getTextStyle(
                fontSize: AppFontSize.micro,
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
                final locked = switch (s.first) {
                  RadioMode.familiar => EcoFeature.radioFamiliar,
                  RadioMode.adventurous => EcoFeature.radioAdventurous,
                  RadioMode.balanced => null,
                };
                if (locked != null && !ecoAllows(context, locked)) return;
                Haptics.selection();
                audio.setRadioMode(s.first);
              },
              style: SegmentedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                selectedForegroundColor: AppColors.textBright,
                selectedBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.25),
                side: const BorderSide(color: AppColors.border),
                textStyle: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              modeDesc,
              style: locale.getTextStyle(
                fontSize: AppFontSize.caption,
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
                        Haptics.confirm();
                        Navigator.of(context).pop();
                        audio.radioMoreLikeThis();
                        messenger.info(strings.radioMoreSnack, icon: Icons.thumb_up_alt_outlined, duration: const Duration(seconds: 3));
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
                        Haptics.confirm();
                        final artist = SongRadio.primaryArtist(current);
                        Navigator.of(context).pop();
                        audio.radioLessLikeThis();
                        messenger.info(strings.radioLessSnack(artist), icon: Icons.thumb_down_alt_outlined, duration: const Duration(seconds: 3));
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
                fontSize: AppFontSize.micro,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Haptics.remove();
                  Navigator.of(context).pop();
                  audio.stopRadio();
                  messenger.info(strings.radioStopped, icon: Icons.sensors_off, duration: const Duration(seconds: 3));
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(strings.radioStop),
                style: TextButton.styleFrom(foregroundColor: AppColors.accentText),
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
                fontSize: AppFontSize.caption,
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
        style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
    );
  }
}
