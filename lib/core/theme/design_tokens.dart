/// The design system's tokens: the only sizes the interface uses.
///
/// A value that isn't here is a value to add here first (and to justify):
/// a scale only stays a scale if nobody writes `fontSize: 11.5` by hand.
/// `tool/design_tokens/migrate.py` maps loose values onto these.
library;

import 'package:flutter/animation.dart';

/// The type scale (D-01). Eight steps; [micro] is the floor for anything
/// that informs (D-02). Only pure ornament (a watermark glyph) goes beyond
/// the scale, and it's built from [mega].
abstract final class AppFontSize {
  /// HUD labels, badges, chips, the Japanese subtitles. The minimum for
  /// text that says something.
  static const double micro = 10;

  /// Captions, secondary lines under a title.
  static const double caption = 11;

  /// Body text, list subtitles.
  static const double body = 12;

  /// Body that leads: list titles, buttons.
  static const double bodyLg = 13;

  /// Card and row titles.
  static const double title = 14;

  /// Section headers, sheet titles.
  static const double titleLg = 16;

  /// Screen titles and big figures in a card.
  static const double headline = 22;

  /// The screen's own name (INICIO // 01), hero numbers.
  static const double display = 28;

  /// A figure that is the whole screen (a cadence, an initial in an avatar).
  static const double hero = 40;

  /// Decorative giants (drop caps, watermark glyphs).
  static const double mega = 64;
}

/// Corner radii (D-03). Four, by what the thing is, not by its size.
abstract final class AppRadius {
  /// Chips, filter buttons, small tags, thumbnails, thin bars: the sharp,
  /// technical corner of the HUD.
  static const double chip = 4;

  /// Cards, tiles, inputs, dialogs.
  static const double card = 12;

  /// Bottom sheets and big panels.
  static const double sheet = 20;

  /// Stadium shapes: badges, pills, round buttons (any height).
  static const double pill = 999;
}

/// Motion (D-04): how long a UI change takes, and how it moves, from a
/// press to the long loops of the ambience. Timers and delays (a retry,
/// a debounce) aren't motion and keep their own times.
abstract final class AppMotion {
  /// A press, a tick, a colour change.
  static const Duration micro = Duration(milliseconds: 100);

  /// Small things appearing: a chip, an icon swap, a fade.
  static const Duration fast = Duration(milliseconds: 200);

  /// The default: a panel, a page, a sheet's content.
  static const Duration normal = Duration(milliseconds: 300);

  /// Big moves: the player opening, a hero flight, a reveal.
  static const Duration slow = Duration(milliseconds: 450);

  /// A value or a scene unfolding: a number counting up, a bar filling,
  /// a shockwave, a long scroll back to the top.
  static const Duration reveal = Duration(milliseconds: 900);

  /// A slower unfolding, for a big moment: Wrapped's numbers, a being
  /// awakening.
  static const Duration revealLong = Duration(milliseconds: 1600);

  /// One turn of a repeating motion: the radar's sweep, the loading moon,
  /// a glow that comes and goes.
  static const Duration cycle = Duration(milliseconds: 1600);

  /// A slow breath: the cover, the moon, a pulse waiting for a voice.
  static const Duration breath = Duration(milliseconds: 2800);

  /// The Ascension's revelation, the app's one long ceremony.
  static const Duration ceremony = Duration(seconds: 9);

  /// Something arriving.
  static const Curve enter = Curves.easeOutCubic;

  /// Something leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Something moving from one place to another.
  static const Curve move = Curves.easeInOutCubic;
}

/// Spacing (D-05).
abstract final class AppSpacing {
  /// The page's side margin: one value for every screen, so titles, cards
  /// and lists line up from one screen to the next.
  static const double page = 16;
}

/// Glass: a surface that lets what's behind it show through, blurred,
/// like frosted glass. Only for what floats over moving content (a
/// header's bar and buttons, a notice), never over plain background,
/// where it would look like nothing. Over glass only white text and
/// icons keep AA whatever passes behind: greys and reds need a solid
/// surface (the sheets stay solid for that).
abstract final class AppGlass {
  /// How far what's behind is blurred.
  static const double blur = 22;

  /// How much of the surface's own colour covers it on a notice: enough
  /// that white text keeps AA (4.5:1) whatever passes behind.
  static const double fill = 0.86;

  /// Liquid glass, for what floats over a page's own fade (a header's
  /// title and buttons): clearer, the page shows through.
  static const double clearFill = 0.55;

  /// The dock (bottom bar, mini player) over the pages: clear enough that
  /// the page shows through, with its labels in white and the lighter
  /// grey (textMuted), which keep AA over the blurred page of a dark app
  /// (its rows and covers averaged by the blur, up to 10% luminance).
  static const double barFill = 0.8;

  /// A round glass button over a picture: clear enough to see it, dark
  /// enough that its white icon keeps 3:1 over a white cover.
  static const double buttonFill = 0.72;

  /// The light caught on the rim: brightest at the top-left, a softer
  /// glint at the bottom-right.
  static const double rimLight = 0.55;
  static const double rimGlint = 0.22;

  /// The sheen that fades down from the top, inside.
  static const double sheen = 0.12;

  /// The soft shadow that lifts it off the page.
  static const double shadow = 0.35;
}
