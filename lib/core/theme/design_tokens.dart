/// The design system's tokens: the only sizes the interface uses.
///
/// A value that isn't here is a value to add here first (and to justify):
/// a scale only stays a scale if nobody writes `fontSize: 11.5` by hand.
/// `tool/design_tokens/migrate.py` maps loose values onto these.
library;

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
