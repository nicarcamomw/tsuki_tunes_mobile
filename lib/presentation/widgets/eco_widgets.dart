import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/app_router.dart';
import '../screens/eco_levels_screen.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import 'haptics.dart';
import 'motion.dart';
import 'swipeable_sheet.dart';

export '../../domain/logic/eco_levels.dart' show EcoFeature, EcoLevels, EcoRank;

/// Each rank's colour: from the dust of the Wanderers to the white light of
/// an ethereal being.
Color ecoRankColor(EcoRank r) => switch (r) {
      EcoRank.errante => const Color(0xFFB8BCC8),
      EcoRank.guerrero => const Color(0xFF4FC3F7),
      EcoRank.senor => const Color(0xFFB26BFF),
      EcoRank.ultra => const Color(0xFFFF3B3B),
      EcoRank.cara => const Color(0xFFFFD166),
      EcoRank.portador => const Color(0xFFFFF0C8),
      EcoRank.oyente => const Color(0xFF64FFDA),
      EcoRank.vidente => const Color(0xFFE040FB),
      EcoRank.etereo => Colors.white,
      EcoRank.inconmensurable => const Color(0xFFFFE9A8),
    };

/// An Observer's colour: no rank, the grey of someone watching from afar.
const ecoObserverColor = Color(0xFF8A8F9E);

/// Sends an Observer to sign in, to become a Bearer.
void becomeBearer(BuildContext context) {
  Haptics.tap();
  context.go(AppPaths.login);
}

/// Whether [f] is open; when it isn't, explains at which level it opens.
/// Call it where a feature starts: `if (!ecoAllows(context, f)) return;`.
bool ecoAllows(BuildContext context, EcoFeature f) {
  if (context.readState(maskProvider).hasFeature(f)) return true;
  Haptics.tap();
  unawaited(showEcoLockedSheet(context, f));
  return false;
}

Future<void> showEcoLockedSheet(BuildContext context, EcoFeature f) => SwipeableSheet.show(
      context,
      initialChildSize: 0.42,
      maxChildSize: 0.6,
      builder: (_, controller) => _LockedSheet(feature: f, controller: controller),
    );

class _LockedSheet extends ConsumerWidget {
  final EcoFeature feature;
  final ScrollController controller;
  const _LockedSheet({required this.feature, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P-04: what it and its EcoProgressBar draw: observer, level, Eco.
    ref.watch(maskProvider.select((m) => (m.isObserver, m.level, m.eco)));
    final masks = ref.read(maskProvider);
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final observer = masks.isObserver;
    final rank = EcoLevels.rankOf(feature.level);
    final color = ecoRankColor(rank);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      children: [
        const SheetHandle(),
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
              child: Icon(Icons.lock_outline_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.ecoFeatureName(feature),
                      style: locale.getTextStyle(fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                  const SizedBox(height: 2),
                  Text((observer ? strings.ecoObserverLocked(feature.level) : strings.ecoOpensAt(feature.level)).toUpperCase(),
                      style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(observer ? strings.ecoObserverBody : strings.ecoLockedBody,
            style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textPrimary, height: 1.4)),
        const SizedBox(height: 16),
        if (!observer) ...[
          EcoProgressBar(masks: masks),
          const SizedBox(height: 18),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: const Color(0xFF111217)),
          onPressed: () {
            Navigator.of(context).pop();
            if (observer) {
              becomeBearer(context);
            } else {
              unawaited(EcoLevelsScreen.open(context));
            }
          },
          icon: Icon(observer ? Icons.login_rounded : Icons.trending_up_rounded, size: 18),
          label: Text(observer ? strings.ecoObserverAction : strings.ecoSeeLevels,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// The level, the rank and how far the next level is.
class EcoProgressBar extends ConsumerWidget {
  final MaskProvider masks;
  const EcoProgressBar({super.key, required this.masks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    if (masks.isObserver) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.ecoObserver.toUpperCase(),
              style: locale.getTextStyle(
                  fontSize: AppFontSize.body, fontWeight: FontWeight.w900, color: ecoObserverColor, letterSpacing: 1.6)),
          const SizedBox(height: 4),
          Text(strings.ecoObserverShort,
              style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary, height: 1.3)),
        ],
      );
    }
    final level = masks.level;
    final rank = masks.rank;
    final color = ecoRankColor(rank);
    final eco = masks.eco;
    final atTop = level >= EcoLevels.maxLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(strings.ecoLevel(level),
                style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(strings.ecoRankName(rank).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: locale.getTextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.4)),
            ),
            const Spacer(),
            if (!atTop)
              Text(strings.ecoAmount(eco),
                  style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        if (atTop)
          // Past 100 no one knows how far the legend is.
          Text(strings.ecoLegendAmount(eco),
              style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w800, color: color, letterSpacing: 1))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: masks.levelProgress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              color: color,
            ),
          ),
        if (!atTop) ...[
          const SizedBox(height: 5),
          Text(strings.ecoToNext(EcoLevels.ecoFor(level + 1) - eco, level + 1),
              style: locale.getTextStyle(fontSize: AppFontSize.caption, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

/// A round level badge: the number in its rank's colour. Opens the levels.
class EcoBadge extends ConsumerWidget {
  final double size;
  const EcoBadge({super.key, this.size = 34});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P-04: the rank follows the level.
    ref.watch(maskProvider.select((m) => (m.isObserver, m.level)));
    final masks = ref.read(maskProvider);
    final strings = ref.watch(localeProvider).strings;
    final observer = masks.isObserver;
    final level = masks.level;
    final color = observer ? ecoObserverColor : ecoRankColor(masks.rank);
    return Semantics(
      button: true,
      label: '${observer ? strings.ecoObserver : strings.ecoLevel(level)}. ${strings.a11yEcoLevels}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          EcoLevelsScreen.open(context);
        },
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF14151D),
            border: Border.all(color: color, width: 1.6),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: size * 0.3)],
          ),
          child: observer
              // An Observer only watches: an eye, not a number.
              ? Icon(Icons.visibility_outlined, size: size * 0.46, color: color)
              : Text('$level',
                  style: TextStyle(fontSize: size * (level >= 100 ? 0.32 : 0.4), fontWeight: FontWeight.w900, color: color)),
        ),
      ),
    );
  }
}

/// [child] dimmed with a lock and the level it opens at, while [feature]
/// is closed. Taps then explain instead of opening.
class EcoLocked extends ConsumerWidget {
  final EcoFeature feature;
  final Widget child;
  final BorderRadius borderRadius;
  const EcoLocked({super.key, required this.feature, required this.child, this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.card))});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(maskProvider.select((m) => m.hasFeature(feature)));
    if (open) return child;
    final strings = ref.watch(localeProvider).strings;
    final color = ecoRankColor(EcoLevels.rankOf(feature.level));
    return Semantics(
      button: true,
      label: '${strings.ecoFeatureName(feature)}. ${strings.ecoOpensAt(feature.level)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          showEcoLockedSheet(context, feature);
        },
        child: Stack(
          children: [
            IgnorePointer(child: Opacity(opacity: 0.38, child: child)),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xE6101118),
                  borderRadius: BorderRadius.circular(AppRadius.sheet),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: color),
                    const SizedBox(width: 3),
                    Text(strings.ecoLevelShort(feature.level),
                        style: TextStyle(fontSize: AppFontSize.micro, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.6)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner for a level reached: the new level, its rank, and what it
/// opened.
class EcoLevelUpBanner extends ConsumerStatefulWidget {
  final int from;
  final int to;
  const EcoLevelUpBanner({super.key, required this.from, required this.to});

  @override
  ConsumerState<EcoLevelUpBanner> createState() => _EcoLevelUpBannerState();
}

class _EcoLevelUpBannerState extends ConsumerState<EcoLevelUpBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _autoClose;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // In at once with less motion asked for; sliding in otherwise.
    if (_enter.isDismissed) {
      if (reduceMotion(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Haptics.success();
    _autoClose = Timer(const Duration(milliseconds: 6500), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _autoClose?.cancel();
    await _enter.reverse();
    if (mounted) ref.read(maskProvider).levelUpShown();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final rank = EcoLevels.rankOf(widget.to);
    final color = ecoRankColor(rank);
    final opened = EcoLevels.rewardsBetween(widget.from, widget.to).where((r) => r.kind != EcoRewardKind.fragment).toList();
    final slide = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - slide.value) * -160),
          child: Opacity(opacity: _enter.value.clamp(0.0, 1.0), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Semantics(
            liveRegion: true,
            button: true,
            label: '${strings.ecoLevelUp}: ${strings.ecoLevel(widget.to)}',
            child: GestureDetector(
              onTap: () { Haptics.tap();
                _close();
                EcoLevelsScreen.open(context);
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) _close();
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sheet),
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.25), AppColors.bgCard]),
                    border: Border.all(color: color.withValues(alpha: 0.75)),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24),
                      const BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF14151D),
                          border: Border.all(color: color, width: 2),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16)],
                        ),
                        child: Text('${widget.to}',
                            style: TextStyle(fontSize: AppFontSize.headline, fontWeight: FontWeight.w900, color: color)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(strings.ecoLevelUp,
                                style: locale.getTextStyle(
                                    fontSize: AppFontSize.micro, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.6)),
                            const SizedBox(height: 2),
                            Text('${strings.ecoLevel(widget.to)} · ${strings.ecoRankName(rank)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: locale.getTextStyle(
                                    fontSize: AppFontSize.titleLg, fontWeight: FontWeight.w900, color: AppColors.textBright)),
                            for (final r in opened.take(3))
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_open_rounded, size: 11, color: color),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(strings.ecoRewardLabel(r),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary)),
                                    ),
                                  ],
                                ),
                              ),
                            if (opened.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(strings.ecoMore(opened.length - 3),
                                    style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textMuted)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact card with the level, the rank and the bar to the next level.
/// Opens the levels.
class EcoLevelCard extends ConsumerWidget {
  final EdgeInsets margin;
  const EcoLevelCard({super.key, this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P-04: what it and its EcoProgressBar draw: observer, level, Eco.
    ref.watch(maskProvider.select((m) => (m.isObserver, m.level, m.eco)));
    final masks = ref.read(maskProvider);
    final strings = ref.watch(localeProvider).strings;
    final color = masks.isObserver ? ecoObserverColor : ecoRankColor(masks.rank);
    return Padding(
      padding: margin,
      child: Semantics(
        button: true,
        label: strings.a11yEcoLevels,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Haptics.tap();
            EcoLevelsScreen.open(context);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                const ExcludeSemantics(child: EcoBadge(size: 44)),
                const SizedBox(width: 12),
                Expanded(child: EcoProgressBar(masks: masks)),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
