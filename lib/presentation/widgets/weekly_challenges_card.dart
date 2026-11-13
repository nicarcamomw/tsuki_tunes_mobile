import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../screens/mask_collection_screen.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import 'haptics.dart';
import 'oni_mask_art.dart';

IconData _iconFor(ChallengeKind kind) => switch (kind) {
      ChallengeKind.newArtists => Icons.person_add_alt_1_rounded,
      ChallengeKind.minutes => Icons.timer_outlined,
      ChallengeKind.plays => Icons.music_note_rounded,
      ChallengeKind.days => Icons.calendar_month_rounded,
      ChallengeKind.night => Icons.nightlight_round,
      ChallengeKind.morning => Icons.wb_twilight_rounded,
      ChallengeKind.rain => Icons.water_drop_outlined,
      ChallengeKind.album => Icons.album_rounded,
      ChallengeKind.guess => Icons.quiz_outlined,
      ChallengeKind.oneArtist => Icons.favorite_border_rounded,
      ChallengeKind.style => Icons.graphic_eq_rounded,
    };

/// This week's three challenges and the masks they give: an R for two, an
/// SR for all three. [compact] is the one-line version for Home, which
/// opens the mask collection.
class WeeklyChallengesCard extends ConsumerWidget {
  final bool compact;

  const WeeklyChallengesCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final challenges = masks.weeklyChallenges;
    final rPrize = masks.weeklyRewardFor(MaskRarity.r);
    final srPrize = masks.weeklyRewardFor(MaskRarity.sr);
    final rWon = masks.weeklyRewardWonFor(MaskRarity.r);
    final srWon = masks.weeklyRewardWonFor(MaskRarity.sr);
    // Home shows the next prize to chase.
    final reward = (!rWon ? rPrize : null) ?? srPrize ?? rPrize;
    final won = reward == null ? false : (reward == srPrize ? srWon : rWon);
    final done = masks.weeklyDoneCount;
    final lang = locale.currentLanguage;

    TextStyle t(double size, {FontWeight w = FontWeight.w700, Color c = AppColors.textBright, double? spacing}) =>
        locale.getTextStyle(fontSize: size, fontWeight: w, color: c, letterSpacing: spacing);

    final header = Row(
      children: [
        const Icon(Icons.flag_rounded, size: 15, color: AppColors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(strings.weeklyTitle,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: t(11, w: FontWeight.w800, c: AppColors.accent, spacing: 1.4)),
        ),
        Text(strings.weeklyTimeLeft(masks.weekTimeLeft), style: t(10, w: FontWeight.w600, c: AppColors.textMuted)),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Haptics.tap();
            MaskCollectionScreen.open(context);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                if (reward != null) _RewardPreview(mask: reward, size: 52, won: won),
                if (reward != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < challenges.length; i++) ...[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: masks.weeklyProgress(challenges[i]) / challenges[i].target,
                                  minHeight: 4,
                                  backgroundColor: AppColors.bgMid,
                                  color: masks.weeklyDone(challenges[i]) ? AppColors.neonGreen : AppColors.accent,
                                ),
                              ),
                            ),
                            if (i < challenges.length - 1) const SizedBox(width: 4),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        won ? reward.name(lang) : strings.weeklyDoneCount(done),
                        style: t(10.5, w: FontWeight.w600, c: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.08), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          for (final c in challenges) _ChallengeRow(challenge: c),
          const Divider(color: AppColors.border, height: 18),
          Row(
            children: [
              for (final (prize, prizeWon, needs) in [(rPrize, rWon, 2), (srPrize, srWon, 3)])
                if (prize != null) ...[
                  Column(
                    children: [
                      _RewardPreview(mask: prize, size: 56, won: prizeWon),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (prizeWon) ...[
                            const Icon(Icons.check_rounded, size: 11, color: AppColors.neonGreen),
                            const SizedBox(width: 2),
                          ],
                          Text(
                            prizeWon ? strings.maskRarity(prize.rarity) : '$needs/3 · ${strings.maskRarity(prize.rarity)}',
                            style: t(9.5, w: FontWeight.w800, c: prizeWon ? AppColors.neonGreen : AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
              Expanded(
                child: Text(
                  rPrize == null && srPrize == null
                      ? strings.weeklyAllCollected
                      : '${strings.weeklyPrizes(rPrize?.name(lang), srPrize?.name(lang))}\n${strings.weeklyPrizesHint}',
                  style: t(11.5, w: FontWeight.w600, c: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeRow extends ConsumerWidget {
  final WeeklyChallenge challenge;
  const _ChallengeRow({required this.challenge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final progress = masks.weeklyProgress(challenge);
    final done = progress >= challenge.target;
    final color = done ? AppColors.neonGreen : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(done ? Icons.check_rounded : _iconFor(challenge.kind), size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.weeklyChallengeText(challenge),
                  style: locale.getTextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.textSecondary : AppColors.textBright,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress / challenge.target,
                          minHeight: 5,
                          backgroundColor: AppColors.bgMid,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$progress/${challenge.target}',
                        style: locale.getTextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The week's prize, shown (dimmed, with a lock) so it's worth chasing.
class _RewardPreview extends StatelessWidget {
  final OniMask mask;
  final double size;
  final bool won;
  const _RewardPreview({required this.mask, required this.size, required this.won});

  @override
  Widget build(BuildContext context) {
    final art = OniMaskArt(mask: mask, size: size, unlocked: true);
    if (won) return art;
    return Stack(
      children: [
        Opacity(opacity: 0.55, child: art),
        Positioned(
          right: size * 0.06,
          bottom: size * 0.06,
          child: Container(
            padding: EdgeInsets.all(size * 0.05),
            decoration: const BoxDecoration(color: AppColors.bgDeep, shape: BoxShape.circle),
            child: Icon(Icons.lock_rounded, size: size * 0.2, color: AppColors.textBright),
          ),
        ),
      ],
    );
  }
}
