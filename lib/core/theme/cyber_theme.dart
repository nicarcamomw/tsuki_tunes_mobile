import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_fonts.dart';
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
      fontFamily: AppFonts.jakarta,
      textTheme: TextTheme(
        displayLarge: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.w900,
          color: AppColors.textBright,
          letterSpacing: 2.0,
        ),
        displayMedium: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.headline,
          fontWeight: FontWeight.w800,
          color: AppColors.textBright,
          letterSpacing: 1.5,
        ),
        headlineSmall: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.titleLg,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 1.0,
        ),
        titleLarge: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.titleLg,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: AppFonts.plusJakartaSans(
          fontSize: AppFontSize.micro,
          fontWeight: FontWeight.w700,
          color: AppColors.accentText,
          letterSpacing: 1.5,
        ),
      ),
      // D-10, three buttons. Primary: white on a deeper crimson (AA, 4.6:1),
      // for the screen's main action. Secondary: a quiet outline, neutral
      // (D-12). Text: the accent's readable red. All with the HUD's chip
      // corner and Android's 48 dp to tap.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentFill,
          foregroundColor: AppColors.textBright,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          textStyle: AppFonts.plusJakartaSans(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderGlow),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          textStyle: AppFonts.plusJakartaSans(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w700),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      // D-14: dialogs and menus rise over the screen.
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surfaceRaised),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.surfaceRaised),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgMid,
        hintStyle: AppFonts.plusJakartaSans(
          color: AppColors.textMuted,
          fontSize: AppFontSize.bodyLg,
        ),
        prefixIconColor: AppColors.accent,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
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
}
