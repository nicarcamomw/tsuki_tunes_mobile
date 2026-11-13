import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/app_router.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';
import '../state/mask_provider.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/haptics.dart';
import 'ascension_screen.dart';

const _bg = Color(0xFF08090E);

/// The Eco levels: where the account stands, how Eco is earned, the player
/// colours the levels opened, all 100 levels with what each opens, and the
/// legend beyond them.
class EcoLevelsScreen extends ConsumerWidget {
  const EcoLevelsScreen({super.key});

  /// Opens the levels, also from above the navigator (the level-up banner).
  static Future<void> open(BuildContext context) {
    final nav = Navigator.maybeOf(context, rootNavigator: true) ?? rootNavigatorKey.currentState;
    return nav?.push(MaterialPageRoute<void>(builder: (_) => const EcoLevelsScreen())) ?? Future.value();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masks = ref.watch(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final level = masks.level;

    final items = <Widget>[
      _Header(masks: masks, locale: locale, strings: strings),
      const SizedBox(height: 22),
      _Label(locale, strings.ecoHowTitle),
      const SizedBox(height: 10),
      _HowToEarn(locale: locale, strings: strings),
      const SizedBox(height: 22),
      _Label(locale, strings.ecoPlayerColor),
      const SizedBox(height: 10),
      _ColorPicker(masks: masks, locale: locale, strings: strings),
      const SizedBox(height: 22),
      _Label(locale, strings.ecoAllLevels),
      const SizedBox(height: 10),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textBright),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.ecoTitle,
            style: locale.getTextStyle(
                fontSize: AppFontSize.title,
                fontWeight: FontWeight.w900,
                color: masks.isObserver ? ecoObserverColor : ecoRankColor(masks.rank),
                letterSpacing: 3)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        itemCount: items.length + EcoLevels.maxLevel + 1,
        itemBuilder: (context, i) {
          if (i < items.length) return items[i];
          final l = i - items.length + 1;
          if (l > EcoLevels.maxLevel) return _Legend(masks: masks, locale: locale, strings: strings);
          // An Observer has reached none: the levels are what a Bearer opens.
          final observer = masks.isObserver;
          return _LevelRow(
              level: l, reached: !observer && level >= l, current: !observer && level == l, locale: locale, strings: strings);
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final LocaleProvider locale;
  final String text;
  const _Label(this.locale, this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 2));
}

class _Header extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _Header({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final observer = masks.isObserver;
    final rank = masks.rank;
    final color = observer ? ecoObserverColor : ecoRankColor(rank);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          center: const Alignment(0, -0.8),
          radius: 1.2,
          colors: [color.withValues(alpha: 0.22), const Color(0xFF12131B), const Color(0xFF0B0B11)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF14151D),
              border: Border.all(color: color, width: 2.5),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 30)],
            ),
            child: observer
                ? Icon(Icons.visibility_outlined, size: 42, color: color)
                : Text('${masks.level}',
                    style: TextStyle(fontSize: masks.level >= 100 ? 32 : 38, fontWeight: FontWeight.w900, color: color)),
          ),
          const SizedBox(height: 12),
          Text((observer ? strings.ecoObserver : strings.ecoRankName(rank)).toUpperCase(),
              textAlign: TextAlign.center,
              style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: color, letterSpacing: 3)),
          const SizedBox(height: 16),
          if (observer) ...[
            Text(strings.ecoObserverBody,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary, height: 1.45)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: ecoRankColor(EcoRank.portador), foregroundColor: const Color(0xFF111217)),
              onPressed: () {
                Navigator.of(context).pop();
                becomeBearer(context);
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text(strings.ecoObserverAction, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ] else
            EcoProgressBar(masks: masks),
          if (masks.choicePending) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFF4D6), foregroundColor: const Color(0xFF111217)),
              onPressed: () { Haptics.tap(); AscensionScreen.open(context); },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(strings.ecoChoicePending, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

class _HowToEarn extends StatelessWidget {
  final LocaleProvider locale;
  final AppStrings strings;
  const _HowToEarn({required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (what, amount) in strings.ecoHowItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(what, style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary)),
                  ),
                  Text(amount,
                      style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w800, color: AppColors.textBright)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The player's colour: the app's red, or one the levels opened.
class _ColorPicker extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _ColorPicker({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final chosen = masks.playerColor?.id;
    final level = masks.unlockLevel; // what's open (all, for an admin)
    Widget dot(String? id, Color color, String name, int? lockedAt) {
      final selected = chosen == id;
      return Semantics(
        button: true,
        selected: selected,
        label: lockedAt == null ? name : '$name. ${strings.ecoOpensAt(lockedAt)}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            Haptics.tap();
            if (lockedAt != null) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.bgCard,
                  content: Text('$name · ${strings.ecoOpensAt(lockedAt)}'),
                ));
              return;
            }
            masks.setPlayerColor(id);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lockedAt == null ? color : color.withValues(alpha: 0.18),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)] : null,
                ),
                child: lockedAt == null
                    ? null
                    : Center(child: Text('$lockedAt', style: const TextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w900, color: AppColors.textMuted))),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: locale.getTextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 10,
      children: [
        dot(null, AppColors.accent, strings.ecoColorDefault, null),
        for (final c in EcoLevels.colors)
          dot(c.id, Color(c.argb), strings.ecoColorName(c), level >= c.level ? null : c.level),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  final int level;
  final bool reached;
  final bool current;
  final LocaleProvider locale;
  final AppStrings strings;
  const _LevelRow({
    required this.level,
    required this.reached,
    required this.current,
    required this.locale,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final rank = EcoLevels.rankOf(level);
    final color = ecoRankColor(rank);
    final rewards = EcoLevels.rewardsAt(level);
    final lang = locale.currentLanguage;
    final startsRank = rank.from == level;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startsRank)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 0, 8),
            child: Row(
              children: [
                Container(width: 14, height: 2, color: color),
                const SizedBox(width: 8),
                Text(strings.ecoRankName(rank).toUpperCase(),
                    style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w900, color: color, letterSpacing: 2)),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
          decoration: BoxDecoration(
            color: current ? color.withValues(alpha: 0.1) : AppColors.bgCard.withValues(alpha: reached ? 1 : 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: current ? color : (reached ? color.withValues(alpha: 0.3) : AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? color : AppColors.bgMid,
                ),
                child: Text('$level',
                    style: TextStyle(
                        fontSize: level >= 100 ? 11 : 13,
                        fontWeight: FontWeight.w900,
                        color: reached ? const Color(0xFF111217) : AppColors.textMuted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in rewards)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: r.kind == EcoRewardKind.fragment
                            ? Text(
                                reached ? '«${r.fragment!.of(lang)}»' : strings.ecoRewardLabel(r),
                                style: locale
                                    .getTextStyle(
                                      fontSize: AppFontSize.body,
                                      color: reached ? AppColors.textPrimary : AppColors.textMuted,
                                      height: 1.35,
                                    )
                                    .copyWith(fontStyle: reached ? FontStyle.italic : FontStyle.normal),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(_iconFor(r), size: 13, color: reached ? color : AppColors.textMuted),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(strings.ecoRewardLabel(r),
                                        style: locale.getTextStyle(
                                            fontSize: AppFontSize.bodyLg,
                                            fontWeight: FontWeight.w700,
                                            color: reached ? AppColors.textBright : AppColors.textMuted)),
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
              if (!reached) const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(EcoReward r) => switch (r.kind) {
        EcoRewardKind.start => Icons.play_arrow_rounded,
        EcoRewardKind.feature => switch (r.feature!) {
            EcoFeature.hearBeings => Icons.hearing_rounded,
            EcoFeature.seeBeings => Icons.visibility_rounded,
            EcoFeature.ethereal => Icons.auto_awesome_rounded,
            _ => Icons.lock_open_rounded,
          },
        EcoRewardKind.sound => Icons.waves_rounded,
        EcoRewardKind.chapter => Icons.menu_book_rounded,
        EcoRewardKind.color => Icons.palette_rounded,
        EcoRewardKind.rank => Icons.military_tech_rounded,
        EcoRewardKind.fragment => Icons.format_quote_rounded,
      };
}

/// Beyond level 100: the level of the Supreme Gods, never reached.
class _Legend extends StatelessWidget {
  final MaskProvider masks;
  final LocaleProvider locale;
  final AppStrings strings;
  const _Legend({required this.masks, required this.locale, required this.strings});

  @override
  Widget build(BuildContext context) {
    final broken = masks.legendReached;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1A10), Color(0xFF0B0B11)],
        ),
        border: Border.all(color: const Color(0xFFFFE9A8).withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: const Color(0xFFFFE9A8).withValues(alpha: 0.12), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFE9A8), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(strings.ecoLegendTitle,
                    style: locale.getTextStyle(
                        fontSize: AppFontSize.body, fontWeight: FontWeight.w900, color: const Color(0xFFFFE9A8), letterSpacing: 1.6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(strings.ecoLegendText,
              style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary, height: 1.45)),
          const SizedBox(height: 14),
          // How much Eco a Supreme God holds is not for anyone to know.
          Text(strings.ecoLegendAmount(masks.eco),
              style: locale.getTextStyle(
                  fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w900, color: const Color(0xFFFFE9A8), letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(broken ? strings.ecoBalanceBroken : strings.ecoLegendNever,
              style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: broken ? const Color(0xFFFFE9A8) : AppColors.textMuted,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}
