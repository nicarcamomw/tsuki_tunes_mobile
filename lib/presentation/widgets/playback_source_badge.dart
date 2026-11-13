import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/logic/playback_source.dart';
import '../state/app_providers.dart';
import '../state/cover_colors.dart';
import 'haptics.dart';
import 'player_tint.dart';
import 'profile_bottom_sheet.dart';
import 'swipeable_sheet.dart';

/// Under the expanded player's controls: whether the whole song plays
/// (Spotify) or a 30-second preview. Tapping it says why.
class PlaybackSourceBadge extends ConsumerWidget {
  const PlaybackSourceBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(playbackSourceProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final label = source.isFullSong ? strings.sourceFullSong : strings.sourcePreview;
    return Semantics(
      button: true,
      label: label,
      hint: source.isFullSong ? strings.sourceFullTitle : strings.sourcePreviewTitle,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Haptics.tap();
          unawaited(showPlaybackSourceSheet(context));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: locale.getTextStyle(fontSize: AppFontSize.micro, color: PlayerTint.of(context), letterSpacing: 2),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 11, color: PlayerTint.of(context).withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// What plays and why, with a way to connect Spotify when that's missing.
Future<void> showPlaybackSourceSheet(BuildContext context) => SwipeableSheet.show(
      context,
      initialChildSize: 0.4,
      maxChildSize: 0.55,
      builder: (_, controller) => _SourceSheet(controller: controller),
    );

class _SourceSheet extends ConsumerWidget {
  final ScrollController controller;
  const _SourceSheet({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(playbackSourceProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final isGuest = ref.watch(authProvider.select((a) => a.isGuest));
    final color = ref.watch(playerTintColorProvider);
    final reason = source.previewReason;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Icon(source.isFullSong ? Icons.graphic_eq_rounded : Icons.timer_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.isFullSong ? strings.sourceFullTitle : strings.sourcePreviewTitle,
                      style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                  const SizedBox(height: 2),
                  Text(source.isFullSong ? strings.sourceFullSong : strings.sourcePreview,
                      style: locale.getTextStyle(
                          fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(reason == null ? strings.sourceFullBody : strings.previewReason(reason),
            style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary, height: 1.4)),
        if (reason == PreviewReason.noSpotify && !isGuest) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: const Color(0xFF111217)),
            onPressed: () {
              Navigator.of(context).pop();
              ProfileBottomSheet.show(context, ref.read(authProvider));
            },
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(strings.spotifyConnect, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }
}
