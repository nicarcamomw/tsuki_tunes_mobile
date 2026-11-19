import 'package:flutter/material.dart';

/// The app's text font, Plus Jakarta Sans, shipped with the app (pubspec
/// `fonts:`, every weight from 200 to 800).
///
/// Perf: it used to come through google_fonts, which downloads it on the
/// first launch and loads it from the disk after that, a moment after the
/// app starts: the first frames (the entrance, the login) were drawn in a
/// fallback font and laid out again when it arrived. Declared with the app,
/// the engine has it before the first frame.
abstract final class AppFonts {
  /// The family name declared in pubspec.yaml.
  static const String jakarta = 'PlusJakartaSans';

  /// A Plus Jakarta Sans style, as google_fonts' plusJakartaSans made one.
  static TextStyle plusJakartaSans({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
    List<FontFeature>? fontFeatures,
  }) =>
      (textStyle ?? const TextStyle()).copyWith(
        fontFamily: jakarta,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationThickness: decorationThickness,
        fontFeatures: fontFeatures,
      );
}
