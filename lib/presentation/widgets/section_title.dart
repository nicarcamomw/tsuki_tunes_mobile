import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/locale_provider.dart';

/// A section's heading: white fading into the accent.
class SectionTitle extends StatelessWidget {
  final LocaleProvider locale;
  final String text;

  /// Lines it may take before it is cut, for headings that share their
  /// row; unlimited when null.
  final int? maxLines;

  const SectionTitle({
    super.key,
    required this.locale,
    required this.text,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.textBright, AppColors.accent],
          stops: [0.5, 1.0],
        ).createShader(bounds),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
          style: locale.getTextStyle(
            fontSize: AppFontSize.bodyLg,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// A group's label: small, muted and in capitals, over a list's groups
/// (settings, search history, Bonds, the queue, search results). Lighter
/// than [SectionTitle], which heads a screen's content sections.
///
/// Read out as a heading. [count] follows it (" · 3"), [marker] puts a
/// short bar of that colour before it, and [trailing] goes after it.
class SectionLabel extends StatelessWidget {
  final LocaleProvider locale;
  final String text;
  final int? count;
  final Color? marker;
  final Widget? trailing;

  const SectionLabel({
    super.key,
    required this.locale,
    required this.text,
    this.count,
    this.marker,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final label = count == null ? text.toUpperCase() : '${text.toUpperCase()} · $count';
    return Semantics(
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (marker != null) ...[
            Container(width: 3, height: 12, color: marker),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: locale.getTextStyle(
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}
