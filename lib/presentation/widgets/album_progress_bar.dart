import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_providers.dart';

class AlbumProgressBar extends ConsumerWidget {
  final int listened;
  final int total;

  const AlbumProgressBar({
    super.key,
    required this.listened,
    required this.total,
  });

  double get progress => total > 0 ? (listened / total).clamp(0.0, 1.0) : 0.0;
  int get percentage => (progress * 100).round();
  bool get isCompleted => listened >= total && total > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Semantics(
      label: '${locale.strings.albumProgressListened(listened, total)}, $percentage%',
      value: '$percentage%',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              locale.strings.albumProgressListened(listened, total),
              style: locale.getTextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$percentage%',
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCompleted ? AppColors.accent : AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                // Fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [AppColors.accent, AppColors.accent.withValues(alpha: 0.8)]
                            : [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCompleted
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.accentGlow,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}
