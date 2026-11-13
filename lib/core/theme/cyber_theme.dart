import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'design_tokens.dart';

class CyberTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDeep,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.textBright,
        surface: AppColors.bgCard,
        onSurface: AppColors.textPrimary,
        secondary: AppColors.neonCyan,
        onSecondary: AppColors.bgDeep,
        outline: AppColors.border,
      ),
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.w900,
          color: AppColors.textBright,
          letterSpacing: 2.0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.headline,
          fontWeight: FontWeight.w800,
          color: AppColors.textBright,
          letterSpacing: 1.5,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.titleLg,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 1.0,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.titleLg,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSize.micro,
          fontWeight: FontWeight.w700,
          color: AppColors.accentText,
          letterSpacing: 1.5,
        ),
      ),
      // Buttons readable at AA: white text on a deeper crimson, and the
      // accent's readable red for text buttons (the default primary red on
      // these backgrounds is under 4.5:1).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentFill,
          foregroundColor: AppColors.textBright,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accentText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.accentText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(foregroundColor: AppColors.accentText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgMid,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMuted,
          fontSize: AppFontSize.bodyLg,
        ),
        prefixIconColor: AppColors.accent,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accentGlow,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),
    );
  }

  // Cyber Box Glow Effect
  static BoxDecoration cyberCardBox({
    Color backgroundColor = AppColors.bgCard,
    Color borderColor = AppColors.border,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: glow ? AppColors.accent : borderColor,
        width: 1,
      ),
      boxShadow: glow
          ? [
              const BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }
}
