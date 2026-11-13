import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/lore/tsuki_lore.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/haptics.dart';
import '../widgets/oni_mask_art.dart';
import '../widgets/oni_mask_colors.dart';
import '../widgets/swipeable_sheet.dart';
import '../widgets/weekly_challenges_card.dart';
import 'lore_screen.dart';

class MaskCollectionScreen extends ConsumerWidget {
  const MaskCollectionScreen({super.key});

  static Future<void> open(BuildContext context) => const MaskCollectionRoute().push(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final equipped = masks.equipped;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.masksTitle,
          style: locale.getTextStyle(
            fontSize: AppFontSize.title,
            fontWeight: FontWeight.w800,
            color: AppColors.textBright,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (equipped?.rarityColor ?? AppColors.border).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    if (equipped != null)
                      OniMaskArt(mask: equipped, size: 92, unlocked: true)
                    else
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppColors.bgMid,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            equipped?.name(locale.currentLanguage) ?? strings.masksNoneYet,
                            style: locale.getTextStyle(
                              fontSize: AppFontSize.titleLg,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textBright,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.masksEquippedHint,
                            style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: masks.unlockedCount / masks.totalCount,
                                    minHeight: 5,
                                    backgroundColor: AppColors.bgMid,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                strings.masksCount(masks.unlockedCount, masks.totalCount),
                                style: locale.getTextStyle(
                                  fontSize: AppFontSize.caption,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textBright,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: EcoLevelCard(margin: EdgeInsets.fromLTRB(16, 0, 16, 16))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _LoreButton(label: strings.loreButton, onTap: () { Haptics.tap(); LoreScreen.open(context); }),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: WeeklyChallengesCard(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _MaskTile(mask: MaskCatalog.all[i]),
                childCount: MaskCatalog.all.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens Tsuki Lore: a moon, gold and night, unlike the rest of the screen.
class _LoreButton extends ConsumerWidget {
  final String label;
  final VoidCallback onTap;
  const _LoreButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    const gold = Color(0xFFFFE9A8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [Color(0xFF241F38), Color(0xFF11111B)]),
            border: Border.all(color: gold.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.12), blurRadius: 16)],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF4EFE0),
                  boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.6), blurRadius: 12)],
                ),
                child: const Text('月', style: TextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: Color(0xFF1A1A28))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, color: gold, letterSpacing: 0.4)),
              ),
              const Icon(Icons.auto_stories_rounded, color: gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaskTile extends ConsumerWidget {
  final OniMask mask;

  const _MaskTile({required this.mask});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final unlocked = masks.isUnlocked(mask.id);
    final isEquipped = masks.equipped?.id == mask.id;
    // From level 90 the beings still asleep can be seen.
    final seen = !unlocked && masks.hasFeature(EcoFeature.seeBeings);
    final hidden = mask.secret && !unlocked && !seen;
    final progress = unlocked ? null : masks.progress(mask.id);

    return Semantics(
      button: true,
      label: hidden ? strings.maskSecretName : mask.name(locale.currentLanguage),
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          _showDetail(context, mask);
        },
        child: Column(
          children: [
            LayoutBuilder(
              builder: (_, c) => Stack(
                clipBehavior: Clip.none,
                children: [
                  if (seen)
                    Opacity(opacity: 0.5, child: OniMaskArt(mask: mask, size: c.maxWidth, unlocked: true))
                  else
                    OniMaskArt(mask: mask, size: c.maxWidth, unlocked: unlocked),
                  if (isEquipped)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hidden ? strings.maskSecretName : mask.name(locale.currentLanguage),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: locale.getTextStyle(
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w700,
                color: unlocked ? AppColors.textBright : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            if (progress != null)
              _ProgressBar(current: progress.$1, goal: progress.$2, color: mask.rarityColor)
            else
              Text(
                mask.weekly
                    ? '${strings.weeklyMaskTag} · ${strings.maskRarity(mask.rarity)}'
                    : strings.maskRarity(mask.rarity),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  fontWeight: FontWeight.w700,
                  color: (unlocked ? mask.rarityColor : AppColors.textMuted).withValues(alpha: 0.9),
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  final int current;
  final int goal;
  final Color color;

  const _ProgressBar({required this.current, required this.goal, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.read(localeProvider);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: goal == 0 ? 0 : current / goal,
              minHeight: 3,
              backgroundColor: AppColors.bgCard,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$current/$goal',
          style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

void _showDetail(BuildContext context, OniMask mask) {
  SwipeableSheet.show(
    context,
    initialChildSize: 0.55,
    maxChildSize: 0.80,
    builder: (_, controller) => _MaskDetail(mask: mask),
  );
}

class _MaskDetail extends ConsumerWidget {
  final OniMask mask;

  const _MaskDetail({required this.mask});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    final unlocked = masks.isUnlocked(mask.id);
    final seen = !unlocked && masks.hasFeature(EcoFeature.seeBeings);
    final hidden = mask.secret && !unlocked && !seen;
    final isEquipped = masks.equipped?.id == mask.id;
    final progress = unlocked ? null : masks.progress(mask.id);
    final at = masks.unlockedAt(mask.id);
    final whisper = _whisperOf(mask, lang);
    final rColor = mask.rarityColor;
    final color = unlocked ? rColor : AppColors.textMuted;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.borderGlow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (seen)
              Opacity(opacity: 0.5, child: OniMaskArt(mask: mask, size: 168, unlocked: true))
            else
              OniMaskArt(mask: mask, size: 168, unlocked: unlocked),
            const SizedBox(height: 16),
            Text(
              hidden ? strings.maskSecretName : mask.name(lang),
              textAlign: TextAlign.center,
              style: locale.getTextStyle(
                fontSize: AppFontSize.headline,
                fontWeight: FontWeight.w900,
                color: AppColors.textBright,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${unlocked ? '${mask.kanji} · ' : ''}${strings.maskRarity(mask.rarity)} · ${strings.maskTierName(mask)}',
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Description / hint
            if (hidden) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_off_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      strings.maskSecretHint,
                      textAlign: TextAlign.center,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textMuted, height: 1.35),
                    ),
                  ),
                ],
              ),
              // A riddle once a few masks are collected.
              if (mask.hint(lang) case final riddle?) ...[
                const SizedBox(height: 12),
                if (masks.secretHintsShown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: rColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: rColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          strings.maskRiddleLabel,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.micro,
                            fontWeight: FontWeight.w800,
                            color: rColor.withValues(alpha: 0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          riddle,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                            fontSize: AppFontSize.bodyLg,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    strings.maskRiddleAfter(MaskProvider.secretHintsAfter),
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
                  ),
              ],
            ]
            else ...[
              if (!unlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 14, color: rColor.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        strings.maskHowToUnlock,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w800,
                          color: rColor.withValues(alpha: 0.7),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  mask.description(lang),
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary, height: 1.35),
                ),
              ),
            ],
            // Progress bar for all locked masks with a goal
            if (progress != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 220,
                child: _ProgressBar(current: progress.$1, goal: progress.$2, color: rColor),
              ),
            ],
            // For locked masks without a numeric goal, show a locked status
            if (!unlocked && !hidden && progress == null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: rColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(
                      strings.maskLocked,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: rColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // From level 75 an awakened being can be heard.
            if (unlocked && whisper != null) ...[
              const SizedBox(height: 14),
              _Whisper(
                text: masks.hasFeature(EcoFeature.hearBeings)
                    ? '«$whisper»'
                    : strings.ecoWhisperLocked(EcoFeature.hearBeings.level),
                heard: masks.hasFeature(EcoFeature.hearBeings),
                color: rColor,
              ),
            ],
            if (at != null) ...[
              const SizedBox(height: 10),
              Text(
                strings.maskUnlockedOn(strings.longDate(at)),
                style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 20),
            if (unlocked)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Haptics.confirm();
                    if (isEquipped) {
                      masks.unequip();
                    } else {
                      masks.equip(mask.id);
                    }
                  },
                  icon: Icon(isEquipped ? Icons.close_rounded : Icons.face_retouching_natural, size: 18),
                  label: Text(
                    isEquipped ? strings.maskUnequip : strings.maskEquip,
                    style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isEquipped ? AppColors.textSecondary : Colors.white,
                    backgroundColor: isEquipped ? AppColors.bgMid.withValues(alpha: 0.5) : rColor.withValues(alpha: 0.25),
                    side: BorderSide(color: isEquipped ? AppColors.border : rColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a being whispers to those who can hear it: its own words for the
/// Five who crossed, its clan's motto, or for the Faces of the Universe,
/// the first words of their legend.
String? _whisperOf(OniMask mask, AppLanguage lang) {
  if (TsukiLore.crossedWhispers[mask.id] case final w?) return w.of(lang);
  final clan = TsukiLore.factionOf(mask.id);
  if (clan != null) return clan.motto.of(lang).replaceAll(RegExp('[«»“”]'), '');
  for (final f in TsukiLore.faces) {
    if (f.mask == mask.id) return f.text.of(lang).split('. ').first.replaceAll(RegExp(r'\.$'), '');
  }
  return null;
}

class _Whisper extends ConsumerWidget {
  final String text;
  final bool heard;
  final Color color;
  const _Whisper({required this.text, required this.heard, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final tone = heard ? color : AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(heard ? Icons.hearing_rounded : Icons.hearing_disabled_rounded, size: 13, color: tone),
              const SizedBox(width: 6),
              Text(strings.ecoWhisper,
                  style: locale.getTextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w800, color: tone, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: locale
                .getTextStyle(fontSize: AppFontSize.bodyLg, color: heard ? AppColors.textPrimary : AppColors.textMuted, height: 1.35)
                .copyWith(fontStyle: heard ? FontStyle.italic : FontStyle.normal),
          ),
        ],
      ),
    );
  }
}
