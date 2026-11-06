import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/lore/tsuki_lore.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/mask_provider.dart';
import '../widgets/lore_text.dart';
import '../widgets/oni_mask_art.dart';

const _gold = Color(0xFFFFE9A8);

/// Tsuki Lore: the world of the masks, by volumes and chapters. Chapters
/// open as the masks they speak of awaken.
class LoreScreen extends ConsumerWidget {
  const LoreScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoreScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(maskProvider.select((m) => m.level));
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07080D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.loreTitle,
            style: locale.getTextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _gold, letterSpacing: 3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _Header(locale: locale, strings: strings, open: TsukiLore.openCount(level), total: TsukiLore.chapters.length),
          for (final tomo in TsukiLore.tomos) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Text(tomo.kanji, style: GoogleFonts.notoSansJp(fontSize: 22, fontWeight: FontWeight.w900, color: _gold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.loreTomo(tomo.numeral),
                          style: locale.getTextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 2)),
                      Text(tomo.title.of(lang),
                          style: locale.getTextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!TsukiLore.tomoOpen(tomo.number, level))
              _ComingSoon(locale: locale, strings: strings, level: TsukiLore.tomoLevel(tomo.number))
            else
              for (final c in TsukiLore.chaptersOf(tomo.number))
                _ChapterTile(chapter: c, open: TsukiLore.isOpen(c, level)),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  final int open;
  final int total;
  const _Header({required this.locale, required this.strings, required this.open, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.2,
          colors: [Color(0xFF2A2440), Color(0xFF12121C), Color(0xFF0A0A12)],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF4EFE0),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
            ),
            alignment: Alignment.center,
            child: Text('月', style: GoogleFonts.notoSansJp(fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.loreSubtitle,
                    style: locale.getTextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textBright, height: 1.25)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : open / total,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(strings.loreChaptersOpen(open, total),
                    style: locale.getTextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;

  /// The Eco level that opens the volume.
  final int level;
  const _ComingSoon({required this.locale, required this.strings, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.ecoOpensAt(level),
                    style: locale.getTextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                Text(strings.ecoLockedBody,
                    style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget {
  final LoreChapter chapter;
  final bool open;
  const _ChapterTile({required this.chapter, required this.open});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    final faction = TsukiLore.faction(chapter.factionId);
    final accent = faction != null ? Color(faction.color) : _gold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open
            ? () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LoreChapterScreen(chapter: chapter)));
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: open ? accent.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: open ? accent.withValues(alpha: 0.45) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: open ? accent.withValues(alpha: 0.14) : AppColors.bgMid,
                  border: Border.all(color: open ? accent.withValues(alpha: 0.6) : AppColors.border),
                ),
                child: open
                    ? Text(chapter.kanji,
                        style: GoogleFonts.notoSansJp(fontSize: 20, fontWeight: FontWeight.w900, color: accent))
                    : const Icon(Icons.lock_rounded, size: 18, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.loreChapter(chapter.numeral),
                        style: locale.getTextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.6)),
                    const SizedBox(height: 2),
                    Text(chapter.title.of(lang),
                        style: locale.getTextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: open ? AppColors.textBright : AppColors.textSecondary)),
                    if (!open) ...[
                      const SizedBox(height: 3),
                      Text(strings.ecoOpensAt(chapter.level),
                          style: locale.getTextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              if (open) Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chapter: its text, and what it tells about the masks in it.
class LoreChapterScreen extends ConsumerWidget {
  final LoreChapter chapter;
  const LoreChapterScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(maskProvider).unlockedIds;
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    final faction = TsukiLore.faction(chapter.factionId);
    final accent = faction != null ? Color(faction.color) : _gold;
    final tomo = TsukiLore.tomos.firstWhere((t) => t.number == chapter.tomo);

    TextStyle body() => locale.getTextStyle(fontSize: 15, color: const Color(0xFFDAD6CC), height: 1.65);

    return Scaffold(
      backgroundColor: const Color(0xFF07080D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07080D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${strings.loreTomo(tomo.numeral)} · ${strings.loreChapter(chapter.numeral)}',
            style: locale.getTextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.6)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 48),
        children: [
          Center(
            child: Text(chapter.kanji,
                style: GoogleFonts.notoSansJp(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  shadows: [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 28)],
                )),
          ),
          const SizedBox(height: 8),
          Text(chapter.title.of(lang),
              textAlign: TextAlign.center,
              style: locale.getTextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textBright, height: 1.2)),
          if (faction != null) ...[
            const SizedBox(height: 6),
            Text(faction.motto.of(lang),
                textAlign: TextAlign.center,
                style: locale.getTextStyle(fontSize: 13, color: accent).copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 22),
          for (final p in chapter.body.of(lang).split('\n\n')) ...[
            LoreText(p, style: body()),
            const SizedBox(height: 14),
          ],
          if (faction != null) _FactionSection(faction: faction, owned: owned),
          if (chapter.id == 'guerras') _BondsSection(bonds: TsukiLore.bonds, owned: owned),
          if (chapter.id == 'cinco') _MaskRow(ids: TsukiLore.crossed, owned: owned),
          if (chapter.id == 'ultras')
            _MaskRow(ids: TsukiLore.ultras, owned: owned),
          if (chapter.id == 'caras')
            for (final f in TsukiLore.faces) _FaceCard(face: f, owned: owned.contains(f.mask)),
        ],
      ),
    );
  }
}

TextStyle _label(LocaleProvider locale, Color color) =>
    locale.getTextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.8);

class _FactionSection extends ConsumerWidget {
  final LoreFaction faction;
  final Set<String> owned;
  const _FactionSection({required this.faction, required this.owned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    final color = Color(faction.color);
    final have = TsukiLore.awakened(faction, owned);
    final total = faction.members.length;
    final leader = MaskCatalog.byId(faction.leader);
    final rival = TsukiLore.faction(faction.rival);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (leader != null)
              _Chip(
                  text: '${strings.loreLeader}: ${owned.contains(leader.id) ? leader.name(lang) : '???'}',
                  color: color),
            if (rival != null) _Chip(text: '${strings.loreRival}: ${rival.name.of(lang)}', color: Color(rival.color)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(strings.loreMembers, style: _label(locale, color)),
            const Spacer(),
            Text('$have/$total', style: _label(locale, AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        _MaskRow(ids: faction.members, owned: owned),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(TsukiLore.complete(faction, owned) ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(strings.loreSecret, style: _label(locale, color)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                TsukiLore.complete(faction, owned) ? faction.secret.of(lang) : strings.loreSecretLocked(have, total),
                style: locale.getTextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
        if (faction.reward case final rewardId?)
          if (MaskCatalog.byId(rewardId) case final reward?) ...[
            const SizedBox(height: 18),
            Text(strings.loreReward, style: _label(locale, color)),
            const SizedBox(height: 10),
            Row(
              children: [
                OniMaskArt(mask: reward, size: 72, unlocked: owned.contains(reward.id)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(owned.contains(reward.id) ? reward.name(lang) : '???',
                          style: locale.getTextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                      const SizedBox(height: 4),
                      Text(owned.contains(reward.id) ? reward.description(lang) : strings.loreRewardHint,
                          style: locale.getTextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        const SizedBox(height: 18),
        _BondsSection(bonds: TsukiLore.bondsOf(faction.members), owned: owned),
      ],
    );
  }
}

class _Chip extends ConsumerWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text, style: locale.getTextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Masks in a wrap: awakened ones in colour, the rest as silhouettes.
class _MaskRow extends StatelessWidget {
  final List<String> ids;
  final Set<String> owned;
  const _MaskRow({required this.ids, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          if (MaskCatalog.byId(id) case final m?) OniMaskArt(mask: m, size: 56, unlocked: owned.contains(id)),
      ],
    );
  }
}

class _BondsSection extends ConsumerWidget {
  final List<LoreBond> bonds;
  final Set<String> owned;
  const _BondsSection({required this.bonds, required this.owned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bonds.isEmpty) return const SizedBox.shrink();
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.loreBonds, style: _label(locale, _gold)),
        const SizedBox(height: 10),
        for (final b in bonds)
          Builder(builder: (context) {
            final known = b.masks.every(owned.contains);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final id in b.masks)
                        if (MaskCatalog.byId(id) case final m?)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: OniMaskArt(mask: m, size: 40, unlocked: owned.contains(id)),
                          ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(strings.loreBondKind(b.kind.name), style: _label(locale, AppColors.textMuted)),
                            Text(known ? b.title.of(lang) : '???',
                                style: locale.getTextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textBright)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(known ? b.text.of(lang) : strings.loreBondLocked,
                      style: locale.getTextStyle(
                          fontSize: 12.5, color: known ? AppColors.textPrimary : AppColors.textMuted, height: 1.45)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _FaceCard extends ConsumerWidget {
  final LoreFace face;
  final bool owned;
  const _FaceCard({required this.face, required this.owned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lang = locale.currentLanguage;
    final mask = MaskCatalog.byId(face.mask)!;
    final god = mask.rarity == MaskRarity.dios;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: god ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: god ? 0.6 : 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OniMaskArt(mask: mask, size: 72, unlocked: owned),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owned ? mask.name(lang) : '???',
                    style: locale.getTextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                Text(face.title.of(lang), style: _label(locale, _gold)),
                const SizedBox(height: 6),
                Text(owned ? face.text.of(lang) : strings.loreFaceVeiled,
                    style: locale.getTextStyle(
                        fontSize: 12.5, color: owned ? AppColors.textPrimary : AppColors.textMuted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
