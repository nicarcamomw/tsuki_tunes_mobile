import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import 'empty_state.dart';

/// A load that failed: an icon, what happened, and a way to try again.
/// The one look every screen uses for it (album, artist, library, search,
/// genre, guess the song), so they don't each repeat their own copy.
class ErrorState extends ConsumerWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
    this.iconSize = 48,
    this.padding = const EdgeInsets.all(24),
  });

  /// What failed, in the app's language.
  final String message;

  /// Tries again; without it there's no button.
  final VoidCallback? onRetry;

  final IconData icon;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: AppColors.textMuted, semanticLabel: strings.a11yOffline),
            const SizedBox(height: 10),
            Text(
              message,
              style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              StateAction(label: strings.retry, onTap: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
