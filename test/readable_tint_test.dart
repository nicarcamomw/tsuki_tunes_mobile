import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';

void main() {
  test('the base red reads as its text shade', () {
    expect(readableTint(AppColors.accent), AppColors.accentText);
  });

  test('a dark cover colour is lifted until it reads at AA', () {
    // A cover's blue and violet, as the cover colours make them (lightness 0.55).
    for (final c in const [Color(0xFF1A1AFF), Color(0xFF8C1AFF)]) {
      expect(contrastRatio(c, AppColors.bgDeep), lessThan(4.5), reason: '$c should start too dark');
      final r = readableTint(c);
      expect(contrastRatio(r, AppColors.bgDeep), greaterThanOrEqualTo(4.5), reason: '$c');
      // And on the player's top, tinted with the cover's own hue.
      final top = HSLColor.fromColor(c).withSaturation(0.6).withLightness(0.16).toColor();
      expect(contrastRatio(r, top), greaterThanOrEqualTo(4.5), reason: '$c on its own background');
      // Still the same colour family: blue stays bluer than red or green.
      expect(r.b, greaterThan(r.g * 0.9), reason: '$c lost its hue');
    }
  });

  test('a light colour comes back as it is', () {
    const yellow = Color(0xFFFFFF1A);
    expect(readableTint(yellow), yellow);
  });

  test('contrast ratio follows WCAG', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFF777777)), 1);
  });
}
