import 'package:flutter/material.dart';

class AppColors {
  // Deep Cyberpunk Dark Palettes (from Tsuki Tunes Web)
  static const Color bgDeep = Color(0xFF14171F);
  static const Color bgMid = Color(0xFF1A1D27);
  static const Color bgCard = Color(0xFF1E212C);
  static const Color bgHover = Color(0xFF252A36);
  static const Color bgGlass = Color(0xF514171F);

  // Borders & Dividers
  static const Color border = Color(0xFF2A2F3D);
  static const Color borderSub = Color(0xFF1A1D27);
  static const Color borderGlow = Color(0xFF3B4255);

  // Cyber Crimson Accent
  static const Color accent = Color(0xFFFF1919);

  // The accent family made to be read (WCAG AA, 4.5:1 on every background
  // here, bgHover the lightest). The brand colours stay for fills, borders,
  // icons and glows; text in them uses these (getTextStyle swaps them in).
  static const Color accentText = Color(0xFFFF5454);
  static const Color neonPurpleText = Color(0xFFC663FF);
  static const Color errorText = Color(0xFFFF4F71);

  /// A deeper crimson behind white text (buttons): white on [accent] is
  /// 3.9:1, on this 4.6:1.
  static const Color accentFill = Color(0xFFED0000);

  /// The readable version of [color] when it's used for text.
  static Color forText(Color color) {
    if (color == accent) return accentText;
    if (color == neonPurple) return neonPurpleText;
    if (color == error) return errorText;
    return color;
  }
  static const Color accentDim = Color(0x26FF1919);
  static const Color accentGlow = Color(0x80FF1919);

  // Neon Complementary Accents
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color neonGreen = Color(0xFF00FF66);

  // Typography
  static const Color textPrimary = Color(0xFFE5E5E5);
  // 4.5:1 on bgHover (it was #888888, 4.05:1).
  static const Color textSecondary = Color(0xFF919191);
  static const Color textMuted = Color(0xFF9DA0AD);
  static const Color textBright = Color(0xFFFFFFFF);

  // Sakura accent (from web stat values)
  static const Color sakura = Color(0xFFFF6B9D);

  // Status & Badges
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF1744);
}
