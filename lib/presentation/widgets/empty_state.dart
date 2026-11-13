import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'haptics.dart';

/// Nothing here yet: art (a mask, an icon), what's missing, why, and
/// optionally what to do about it. The one look every empty list uses
/// (library, playlists, search, queue, Bonds, radar, Rabbit Hole, the
/// listening clock, Wrapped), as [ErrorState] is for a failed load.
class EmptyState extends ConsumerWidget {
  const EmptyState({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.image,
    this.art,
    this.artLabel,
    this.tone,
    this.actionLabel,
    this.actionSemanticLabel,
    this.onAction,
    this.compact = false,
    this.padding,
    this.lore,
  }) : assert(title != null || message != null, 'say what is missing');

  /// What's missing, short (in capitals like a HUD line, except [compact]).
  final String? title;

  /// Why, or how to fill it.
  final String? message;

  /// An icon as the art…
  final IconData? icon;

  /// …or an image asset (the masks: Tengu, Oni, Hannya)…
  final String? image;

  /// …or any widget (a kanji, an illustration).
  final Widget? art;

  /// What TalkBack says for the art; without it the art is decoration.
  final String? artLabel;

  /// The colour of the icon and the action (cyan for information, purple
  /// for discovery and masks, the accent by default: D-12).
  final Color? tone;

  final String? actionLabel;

  /// What TalkBack says for the action when its label alone is too short.
  final String? actionSemanticLabel;

  final VoidCallback? onAction;

  /// Tighter, for a section inside a list (the queue).
  final bool compact;

  final EdgeInsetsGeometry? padding;

  /// P-06: a line of lore told by the mask in [image]; with it the mask is
  /// drawn large, as the state's character.
  final String? lore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final character = lore != null && image != null;
    final artSize = character ? 96.0 : compact ? 40.0 : 54.0;
    final Widget? artWidget = art ??
        (image != null
            ? Opacity(
                opacity: character ? 0.55 : 0.3,
                child: Image.asset(image!,
                    width: artSize, height: artSize, semanticLabel: artLabel, excludeFromSemantics: artLabel == null),
              )
            : icon != null
                ? Icon(icon,
                    size: compact ? 36 : 40,
                    color: (tone ?? AppColors.textMuted).withValues(alpha: tone == null ? 0.7 : 0.75),
                    semanticLabel: artLabel)
                : null);

    final content = Padding(
        padding: padding ?? EdgeInsets.symmetric(horizontal: 28, vertical: compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (artWidget != null) ...[artWidget, SizedBox(height: compact ? 8 : 12)],
            if (title != null)
              Text(
                compact ? title! : title!.toUpperCase(),
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: compact ? AppFontSize.body : AppFontSize.bodyLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            if (title != null && message != null) const SizedBox(height: 6),
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: compact ? AppFontSize.caption : AppFontSize.body,
                  color: title == null ? AppColors.textSecondary : AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            if (lore != null) ...[
              const SizedBox(height: 10),
              Text(
                lore!,
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  color: AppColors.textMuted,
                  height: 1.45,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 8 : 16),
              StateAction(
                label: actionLabel!,
                semanticLabel: actionSemanticLabel,
                tone: tone ?? AppColors.accent,
                onTap: onAction!,
              ),
            ],
          ],
        ),
      );
    // Centred when it fits; on a small phone or with large text, where it
    // overflowed its space, it scrolls instead.
    return LayoutBuilder(builder: (context, box) {
      if (!box.hasBoundedHeight) return Center(child: content);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(child: content),
        ),
      );
    });
  }
}

/// The button under an empty or failed state: a tinted outline, 48 dp to
/// tap however small it looks. Shared by [EmptyState] and [ErrorState].
class StateAction extends ConsumerWidget {
  const StateAction({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.tone = AppColors.accent,
  });

  final String label;
  final String? semanticLabel;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: tone.withValues(alpha: 0.5)),
              ),
              child: Text(
                label.toUpperCase(),
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w800,
                  color: tone,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
