import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_font_size.dart';

class GlitchText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final bool hasGlow;
  final double letterSpacing;

  const GlitchText(
    this.text, {
    super.key,
    this.fontSize = AppFontSize.heading,
    this.fontWeight = FontWeight.w700,
    this.color = AppColors.textBright,
    this.hasGlow = false,
    this.letterSpacing = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        shadows: hasGlow
            ? [
                const BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
