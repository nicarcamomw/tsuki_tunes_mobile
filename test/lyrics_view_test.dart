import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/widgets/lyrics_view.dart';

Uint8List _pixels(List<Color> colors) => Uint8List.fromList([
      for (final c in colors) ...[
        (c.r * 255).round(),
        (c.g * 255).round(),
        (c.b * 255).round(),
        255,
      ],
    ]);

void main() {
  group('AlbumTint.fromPixels', () {
    test('picks the vivid color over greys, darkened for white text', () {
      final tint = AlbumTint.fromPixels(_pixels([
        for (var i = 0; i < 30; i++) const Color(0xFF808080),
        for (var i = 0; i < 10; i++) const Color(0xFF1E90FF),
      ]));
      final hsl = HSLColor.fromColor(tint);
      expect(hsl.hue, closeTo(HSLColor.fromColor(const Color(0xFF1E90FF)).hue, 12));
      expect(hsl.lightness, closeTo(0.24, 0.01));
      expect(hsl.saturation, greaterThanOrEqualTo(0.45));
    });

    test('grey or black covers fall back to the crimson', () {
      expect(
        AlbumTint.fromPixels(_pixels([
          for (var i = 0; i < 20; i++) const Color(0xFF777777),
        ])),
        AlbumTint.fallback,
      );
      expect(
        AlbumTint.fromPixels(_pixels([
          for (var i = 0; i < 20; i++) const Color(0xFF050505),
        ])),
        AlbumTint.fallback,
      );
    });
  });
}
