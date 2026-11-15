import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../navigation/main_tab.dart';
import '../state/locale_provider.dart';
import 'cyber_nav_icon.dart';
import 'motion.dart';
import 'tap_scale.dart';

/// The bottom bar's four tabs, on the dock's glass.
///
/// The active tab sits in a lens of lighter glass with a red light at its
/// foot; changing tabs, the lens slides over, stretching like a drop (its
/// leading edge ahead, its trailing edge catching up). Every tab is the
/// same height, so nothing moves but the lens. Library carries a count of
/// the songs marked elsewhere since it was last seen.
///
/// For TalkBack it's a tab bar: "Home, tab 1 of 4, selected"; holding a
/// tab says it shows shortcuts.
class TsukiNavBar extends StatefulWidget {
  const TsukiNavBar({
    super.key,
    required this.selected,
    required this.locale,
    required this.onTap,
    required this.onLongPress,
    this.newInLibrary = 0,
  });

  final MainTab selected;
  final LocaleProvider locale;
  final ValueChanged<MainTab> onTap;

  /// With the tab's box on screen, to anchor its shortcuts.
  final void Function(MainTab tab, Rect anchor) onLongPress;

  /// Songs marked since Library was last open (0: no badge).
  final int newInLibrary;

  /// A tab's height: the lens, the icon, the name and the Japanese line.
  static const double itemHeight = 66;

  static const Key lensKey = ValueKey('nav-lens');

  @override
  State<TsukiNavBar> createState() => _TsukiNavBarState();
}

class _TsukiNavBarState extends State<TsukiNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this, duration: AppMotion.slow, value: 1);
  late double _from = widget.selected.index.toDouble();
  late double _to = _from;

  @override
  void didUpdateWidget(covariant TsukiNavBar old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    final (left, right) = _edges();
    // From wherever the lens is now, even mid-way.
    _from = (left + right) / 2;
    _to = widget.selected.index.toDouble();
    if (reduceMotion(context)) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  /// The lens's left and right edges, in tab slots (0 = the first tab's
  /// centre): the edge it moves towards leads, the other catches up.
  (double, double) _edges() {
    final t = _move.value;
    final lead = Curves.easeOutCubic.transform(t);
    final trail = Curves.easeInOutCubic.transform(t);
    final ahead = _from + (_to - _from) * lead;
    final behind = _from + (_to - _from) * trail;
    return _to >= _from ? (behind, ahead) : (ahead, behind);
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.locale.strings;
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        height: TsukiNavBar.itemHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / MainTab.values.length;
            final lensWidth = (slot - 14).clamp(48.0, 92.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // The lens, under the tabs.
                AnimatedBuilder(
                  animation: _move,
                  builder: (context, _) {
                    final (left, right) = _edges();
                    final l = slot * (left + 0.5) - lensWidth / 2;
                    final r = slot * (right + 0.5) + lensWidth / 2;
                    return Positioned(
                      key: TsukiNavBar.lensKey,
                      left: l,
                      width: r - l,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(child: _Lens()),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in MainTab.values)
                      Expanded(
                        child: _NavItem(
                          tab: tab,
                          selected: tab == widget.selected,
                          label: _label(tab),
                          locale: widget.locale,
                          badge: tab == MainTab.library ? widget.newInLibrary : 0,
                          semantics: [
                            _label(tab),
                            strings.navTabOf(tab.index + 1, MainTab.values.length),
                            if (tab == MainTab.library && widget.newInLibrary > 0) strings.navNewTracks(widget.newInLibrary),
                          ].join(', '),
                          holdHint: strings.navHoldHint,
                          onTap: () => widget.onTap(tab),
                          onLongPress: (rect) => widget.onLongPress(tab, rect),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _label(MainTab tab) {
    final s = widget.locale.strings;
    return switch (tab) {
      MainTab.home => s.navHome,
      MainTab.search => s.navSearch,
      MainTab.explore => s.navExplore,
      MainTab.library => s.navLibrary,
    };
  }
}

/// The active tab's lens: lighter glass, a lit rim along the top, and a
/// red light at its foot.
class _Lens extends StatelessWidget {
  const _Lens();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.11), Colors.white.withValues(alpha: 0.04)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 18,
            height: 3,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.7), blurRadius: 8)],
            ),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.label,
    required this.locale,
    required this.badge,
    required this.semantics,
    required this.holdHint,
    required this.onTap,
    required this.onLongPress,
  });

  final MainTab tab;
  final bool selected;
  final String label;
  final LocaleProvider locale;
  final int badge;
  final String semantics;
  final String holdHint;
  final VoidCallback onTap;
  final ValueChanged<Rect> onLongPress;

  Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.tab,
      container: true,
      selected: selected,
      label: semantics,
      onTap: onTap,
      onLongPress: () => onLongPress(_rectOf(context)),
      onLongPressHint: holdHint,
      child: ExcludeSemantics(
        child: TapScale(
          onTap: onTap,
          onLongPress: () => onLongPress(_rectOf(context)),
          scaleDown: 0.88,
          child: SizedBox(
            width: double.infinity,
            height: TsukiNavBar.itemHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CyberNavIcon(tab: tab, isSelected: selected, size: 24),
                    Positioned(top: -5, left: 15, child: _Badge(count: badge, locale: locale)),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 13,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: locale.getTextStyle(
                        fontSize: AppFontSize.micro,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.accentText : AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                      child: Text(label, maxLines: 1),
                    ),
                  ),
                ),
                // E-01: the Japanese HUD line is ornament, on the active tab
                // only; it keeps its room so nothing moves.
                SizedBox(
                  height: 12,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: AppMotion.fast,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        locale.strings.navHudSubtitle(tab.name),
                        maxLines: 1,
                        style: GoogleFonts.notoSansJp(
                          fontSize: AppFontSize.micro,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentText.withValues(alpha: 0.75),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
                // Room for the lens's light at its foot.
                const SizedBox(height: 9),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Library's count of new songs: pops in, and pops again when it grows.
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.locale});

  final int count;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: count <= 0
          ? const SizedBox.shrink(key: ValueKey(0))
          : Container(
              key: ValueKey(count),
              constraints: const BoxConstraints(minWidth: 18),
              height: 15,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentFill,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surface, width: 1.4),
                boxShadow: const [BoxShadow(color: AppColors.accentGlow, blurRadius: 6)],
              ),
              child: Text(
                count > 9 ? '9+' : '+$count',
                style: locale.getTextStyle(
                  fontSize: AppFontSize.micro,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBright,
                  height: 1,
                  tabular: true,
                ),
              ),
            ),
    );
  }
}
