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
