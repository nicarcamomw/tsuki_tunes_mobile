import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'listened_undo.dart';
import 'radio_control_sheet.dart' show radioReasonLabel;

/// Under the player's title while a song smart shuffle recommended plays:
/// that it's a recommendation and why ("because you listen to X"), and a
/// one-tap "Keep" that saves it to the library, after which it's one of
/// the user's songs. Nothing for any other song.
class RecommendedLine extends ConsumerWidget {
  const RecommendedLine({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (recommended, reason) = ref.watch(audioProvider.select(
        (a) => (a.isRecommended(track.id), a.recommendationReasonFor(track.id))));
    if (!recommended) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final why = radioReasonLabel(strings, reason);
    final guest = ref.watch(authProvider.select((a) => a.isGuest));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.accent),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      why == null ? strings.recommendedTag : '${strings.recommendedTag} · $why',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentText,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Guests have no library to keep it in.
          if (!guest) ...[
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () {
                Haptics.confirm();
                final audio = ref.read(audioProvider);
                if (!ref.read(libraryProvider).isTrackListened(track.id)) {
                  unawaited(toggleListenedWithUndo(context, ref, track));
                }
                audio.keepRecommendation(track.id);
              },
              icon: const Icon(Icons.bookmark_add_rounded, size: 16),
              label: Text(strings.recoKeep,
                  style: locale.getTextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              // Secondary: the theme's outline, compact beside the chip.
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBright,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
