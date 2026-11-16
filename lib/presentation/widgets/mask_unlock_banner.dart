import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/lore/tsuki_lore.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import 'celebration.dart';
import 'eco_widgets.dart';
import 'haptics.dart';
import 'motion.dart';
import 'oni_mask_art.dart';
import 'oni_mask_colors.dart';
import 'player_tint.dart';

/// App-wide layer that announces newly unlocked masks, one at a time, then a
/// level reached. How a mask is announced follows how rare it is:
///
/// - R and SR: a capsule of glass at the top, in the rarity's colour.
/// - SSR: the same, with a sheen of light crossing the mask.
/// - UL, the divine ones and the one from another universe: a moment of
///   their own, the whole screen, the mask in its light ([GrandUnlock]).
class MaskUnlockLayer extends ConsumerWidget {
  final Widget child;

  /// Opens the collection when an announcement is tapped.
  final VoidCallback? onOpenCollection;

  const MaskUnlockLayer({super.key, required this.child, this.onOpenCollection});

  /// Whether [mask] gets the whole screen.
  static bool isGrand(OniMask mask) =>
      mask.rarity == MaskRarity.ul || mask.rarity == MaskRarity.dios || TsukiLore.strangers.contains(mask.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(maskProvider.select((m) => m.pendingCelebration));
    final mask = MaskCatalog.byId(pending);
    // A level reached waits for the masks to be announced first.
    final levelUp = ref.watch(maskProvider.select((m) => m.pendingLevelUp));
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (mask != null && isGrand(mask))
          Positioned.fill(
            child: GrandUnlock(key: ValueKey('grand-${mask.id}'), mask: mask, onOpen: onOpenCollection),
          )
        else if (mask != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _UnlockBanner(key: ValueKey(mask.id), mask: mask, onOpen: onOpenCollection),
          )
        else if (levelUp != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: EcoLevelUpBanner(key: ValueKey('lv${levelUp.$2}'), from: levelUp.$1, to: levelUp.$2),
          ),
      ],
    );
  }
}

/// The light a mask is announced in: its aura where it has one (the UL and
/// divine ones, the stranger's cold metal), else its rarity's colour.
Color unlockColor(OniMask mask) => mask.playerAura ?? mask.rarityColor;

class _UnlockBanner extends ConsumerStatefulWidget {
  final OniMask mask;
  final VoidCallback? onOpen;

  const _UnlockBanner({super.key, required this.mask, this.onOpen});

  @override
  ConsumerState<_UnlockBanner> createState() => _UnlockBannerState();
}

class _UnlockBannerState extends ConsumerState<_UnlockBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: AppMotion.revealLong);

  @override
  void initState() {
    super.initState();
    Haptics.success();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _burst.value = 1;
    } else if (_burst.isDismissed) {
      _burst.forward();
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final mask = widget.mask;
    final color = unlockColor(mask);
    final description = mask.description(locale.currentLanguage);
    return CelebrationBanner(
      color: color,
      locale: locale,
      overline: '${strings.maskUnlockedTitle} · ${strings.maskTierName(mask)}',
      title: '${mask.kanji}  ${mask.name(locale.currentLanguage)}',
      readText: description,
      shimmer: mask.rarity == MaskRarity.ssr,
      onOpen: widget.onOpen,
      onDone: () => ref.read(maskProvider).dismissCelebration(),
      leading: AnimatedBuilder(
        animation: _burst,
        builder: (context, _) => CustomPaint(
          painter: BurstPainter(_burst.value, color),
          child: Transform.scale(
            scale: 0.6 + 0.4 * Curves.elasticOut.transform(_burst.value.clamp(0.0, 1.0)),
            child: OniMaskArt(mask: mask, size: 64, unlocked: true),
          ),
        ),
      ),
      details: [
        const SizedBox(height: 2),
        Text(
          description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: locale.getTextStyle(fontSize: AppFontSize.caption, color: AppColors.textSecondary, height: 1.35),
        ),
      ],
    );
  }
}

/// A UL, a divine mask or the stranger: the screen dims, the mask rises in
/// its own light with rays flying out, its kind and its name below. Stays
/// to be seen, then goes; a tap opens the collection.
class GrandUnlock extends ConsumerStatefulWidget {
  const GrandUnlock({super.key, required this.mask, this.onOpen});

  final OniMask mask;
  final VoidCallback? onOpen;

  /// How long it stays (to read it), unless tapped.
  static const Duration stay = Duration(milliseconds: 4200);

  @override
  ConsumerState<GrandUnlock> createState() => _GrandUnlockState();
}

class _GrandUnlockState extends ConsumerState<GrandUnlock> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: AppMotion.slow);
  late final AnimationController _rise = AnimationController(vsync: this, duration: AppMotion.revealLong);
  Timer? _leave;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    Haptics.grand();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_in.isDismissed || _leave != null) return;
    if (reduceMotion(context)) {
      _in.value = 1;
      _rise.value = 1;
    } else {
      _in.forward();
      _rise.forward();
    }
    final talkBack = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    _leave = Timer(talkBack ? GrandUnlock.stay * 2 : GrandUnlock.stay, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _leave?.cancel();
    if (reduceMotion(context)) {
      _in.value = 0;
    } else {
      await _in.reverse();
    }
    if (mounted) ref.read(maskProvider).dismissCelebration();
  }

  @override
  void dispose() {
    _leave?.cancel();
    _in.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final mask = widget.mask;
    final color = unlockColor(mask);
    final stranger = TsukiLore.strangers.contains(mask.id);
    final tier = stranger ? strings.maskStrangerTier : strings.maskTierName(mask);
    final name = mask.name(locale.currentLanguage);
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        button: widget.onOpen != null,
        label: '${strings.maskUnlockedTitle}: $tier, $name',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.tap();
              unawaited(_close());
              widget.onOpen?.call();
            },
            child: AnimatedBuilder(
              animation: Listenable.merge([_in, _rise]),
              builder: (context, _) {
                final shown = Curves.easeOut.transform(_in.value);
                final rise = _rise.value;
                final pop = Curves.easeOutBack.transform(rise.clamp(0.0, 1.0));
                return Opacity(
                  opacity: shown,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The world dims; the mask's light rises from the middle.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.9,
                            colors: [
                              Color.lerp(AppColors.ink, color, 0.22)!.withValues(alpha: 0.92),
                              AppColors.ink.withValues(alpha: 0.94),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 260,
                              height: 260,
                              child: CustomPaint(
                                painter: BurstPainter(rise, color, rays: 18, reach: 1.1),
                                child: Center(
                                  child: Transform.translate(
                                    offset: Offset(0, 24 * (1 - pop)),
                                    child: Transform.scale(
                                      scale: 0.7 + 0.3 * pop,
                                      // A soft halo of its light, fading out
                                      // (not a disc).
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0.12), color.withValues(alpha: 0)],
                                            stops: const [0, 0.55, 1],
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: OniMaskArt(mask: mask, size: 180, unlocked: true, frame: false),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: Curves.easeOut.transform(((rise - 0.35) / 0.4).clamp(0.0, 1.0)),
                              child: Column(
                                children: [
                                  Text(
                                    tier,
                                    style: locale.getTextStyle(
                                      fontSize: AppFontSize.caption,
                                      fontWeight: FontWeight.w900,
                                      color: readableTint(color),
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mask.kanji,
                                    style: locale.getTextStyle(
                                      fontSize: AppFontSize.hero,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textBright,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      style: locale.getTextStyle(
                                        fontSize: AppFontSize.headline,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textBright,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    strings.maskGrandHint,
                                    style: locale.getTextStyle(fontSize: AppFontSize.body, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
