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
  //
  // D-12, red with a meaning. The crimson is for three things only:
  //   1. what is playing (the current song's row, the play button, the
  //      progress),
  //   2. the screen's main action (play all, create, the primary button),
  //   3. what is active or selected (the tab, a chosen chip, a toggle on),
  // plus the brand's own marks (the "// 01" of a screen title, the logo).
  // Everything else that informs (counts, section headers, secondary
  // actions, links) is neutral: textPrimary / textSecondary / textMuted.
  // The neons each keep one meaning: cyan = ambient and information
  // (weather, moon, radar, hints), purple = social and the masks (Bonds,
  // shared playlists, seres etéreos), green = Spotify and running.
  static const Color accent = Color(0xFFFF1919);

  /// D-12 by name, for new code: what sounds, the main action, what's on.
  static const Color playing = accent;
  static const Color primaryAction = accent;
  static const Color active = accent;

  /// D-12: the neons' fixed meanings.
  static const Color info = neonCyan;
  static const Color social = neonPurple;
  static const Color spotify = neonGreen;

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

  // The shrine (D-11, P-05): the palette of the progression screens (Eco
  // levels, streak, masks, Lore, ascension), one ink-and-moonlight world
  // instead of each screen's own near-identical darks.
  static const Color shrineBg = Color(0xFF08090E);
  static const Color shrineCardDeep = Color(0xFF0C0D13);
  static const Color shrineCard = Color(0xFF111217);
  static const Color shrineBorder = Color(0xFF1A1A28);
  /// The masks' violet dusk (gradients behind a being).
  static const Color shrineViolet = Color(0xFF272140);
  /// Gold's shadow (behind the gold of a reward or a level).
  static const Color shrineGoldDeep = Color(0xFF1C1A10);
  static const Color gold = Color(0xFFFFE9A8);
  static const Color moonlight = Color(0xFFFFF4D6);
  /// Paper-white for a title in the shrine.
  static const Color parchment = Color(0xFFF4EFE0);
  /// The Lore's reading colour: warm, softer than white on the ink.
  static const Color loreBody = Color(0xFFDAD6CC);
  /// The streak's embers.
  static const Color emberInk = Color(0xFF181010);
  static const Color ember = Color(0xFF2A1206);
  static const Color emberGlow = Color(0xFF3A1A0C);
}
