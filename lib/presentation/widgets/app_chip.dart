import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'haptics.dart';
import 'tap_scale.dart';

/// A choice among a few (L-02): the library's order, search's tabs. Red
/// fill when chosen (D-12: what's active), a quiet outline otherwise;
/// 48 dp to tap however small it looks.
class AppChip extends ConsumerWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// What TalkBack says, when [label] alone is too short.
  final String? semanticLabel;

  /// Fills its slot (a row of equal choices) instead of hugging its label.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: TapScale(
        scaleDown: 0.93,
        haptic: Haptics.selection,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            heightFactor: 1,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.move,
              width: expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.bgMid,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: selected ? AppColors.accent : AppColors.border),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textBright : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
