import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import 'motion.dart';

/// The header of every detail page (artist, album, playlist), T-01: the
/// same height, the same collapse (the picture slides away under a
/// parallax and the name fades into the bar) and the same round buttons.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.background,
    required this.backLabel,
    this.actions = const [],
    this.onBack,
  });

  /// One height for the three, so going artist → album → playlist doesn't
  /// jump.
  static const double expandedHeight = 280;

  /// The page's name, shown in the bar once the header has collapsed.
  final String title;

  /// What fills the expanded header (a photo, a cover, a gradient).
  final Widget background;

  /// What TalkBack says for the back button.
  final String backLabel;

  /// [DetailHeaderButton]s (or a menu wearing one).
  final List<Widget> actions;

  /// Instead of popping the page.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.bgDeep,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: DetailHeaderButton(
        icon: Icons.arrow_back_rounded,
        tooltip: backLabel,
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      actions: [...actions, const SizedBox(width: 4)],
      flexibleSpace: _CollapsingSpace(title: title, background: background),
    );
  }
}

class _CollapsingSpace extends StatelessWidget {
  const _CollapsingSpace({required this.title, required this.background});

  final String title;
  final Widget background;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    // 1 fully open, 0 collapsed to the bar.
    final open = settings == null || settings.maxExtent == settings.minExtent
        ? 1.0
        : ((settings.currentExtent - settings.minExtent) / (settings.maxExtent - settings.minExtent)).clamp(0.0, 1.0);
    // The name shows in the bar over the last fifth of the collapse.
    final titleOpacity = (1 - open / 0.2).clamp(0.0, 1.0);
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlexibleSpaceBar(
          collapseMode: reduceMotion(context) ? CollapseMode.pin : CollapseMode.parallax,
          background: background,
        ),
        Positioned(
          top: topInset,
          left: 64,
          right: 64,
          height: kToolbarHeight,
          child: IgnorePointer(
            child: ExcludeSemantics(
              // The page says its name in the header already.
              excluding: titleOpacity < 1,
              child: Opacity(
                opacity: titleOpacity,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBright,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A round button of the detail header: readable over any picture (a
/// dark disc, a thin border), 48 dp to tap. Neutral (D-12): the page's
/// main action lives under the header, in red.
class DetailHeaderButton extends StatelessWidget {
  const DetailHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textBright,
    this.child,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  /// Replaces the icon (a progress ring, the Oni mask).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: DetailHeaderDisc(child: child ?? Icon(icon, color: color, size: 20, semanticLabel: tooltip)),
    );
  }
}

/// The dark disc behind a header button's icon.
class DetailHeaderDisc extends StatelessWidget {
  const DetailHeaderDisc({super.key, required this.child, this.highlighted = false});

  final Widget child;

  /// A thin accent ring (the artist's completed mask).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.35),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}
