import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';

double _lightness(Color c) => HSLColor.fromColor(c).lightness;
double _hue(Color c) => HSLColor.fromColor(c).hue;

void main() {
  group('CoverColors.fromSeed', () {
    test('a dark cover gives an accent bright enough to read', () {
      final colors = CoverColors.fromSeed(const Color(0xFF0A1A40))!; // navy
      expect(_lightness(colors.accent), greaterThanOrEqualTo(0.55));
      expect(_hue(colors.accent), closeTo(_hue(const Color(0xFF0A1A40)), 1));
    });

    test('a pale cover gives an accent that is not washed out', () {
      final colors = CoverColors.fromSeed(const Color(0xFFFFD6E0))!; // pastel pink
      expect(_lightness(colors.accent), lessThanOrEqualTo(0.72));
    });

    test('the background stays dark so white text reads on it', () {
      for (final seed in const [Color(0xFFFFEB3B), Color(0xFF00E5FF), Color(0xFF8B0000)]) {
        final bg = CoverColors.fromSeed(seed)!.background;
        expect(_lightness(bg), closeTo(0.16, 0.01), reason: '$seed');
        expect(ThemeData.estimateBrightnessForColor(bg), Brightness.dark, reason: '$seed');
      }
    });

    test('a black, white or grey cover keeps the player colour', () {
      expect(CoverColors.fromSeed(const Color(0xFF000000)), isNull);
      expect(CoverColors.fromSeed(const Color(0xFFFFFFFF)), isNull);
      expect(CoverColors.fromSeed(const Color(0xFF808080)), isNull);
    });
  });

  group('dominantArgb', () {
    Uint32List image(List<int> colours) {
      // 64x64, filled with the colours in equal bands.
      final out = Uint32List(64 * 64);
      for (var i = 0; i < out.length; i++) {
        out[i] = colours[i * colours.length ~/ out.length];
      }
      return out;
    }

    test('a mostly red cover gives a red', () async {
      final argb = await dominantArgb(image([0xFFD32F2F, 0xFFD32F2F, 0xFFD32F2F, 0xFF202020]));
      final hue = HSLColor.fromColor(Color(argb!)).hue;
      expect(hue < 15 || hue > 345, isTrue, reason: 'hue $hue');
    });

    test('a vivid colour wins over a larger dull one', () async {
      final argb = await dominantArgb(image([0xFF555555, 0xFF555555, 0xFF555555, 0xFF00C8FF]));
      expect(HSLColor.fromColor(Color(argb!)).hue, closeTo(193, 15));
    });

    test('black and white gives no colour, not a default blue', () async {
      expect(await dominantArgb(image([0xFF000000, 0xFFFFFFFF, 0xFF808080])), isNull);
    });

    test('a transparent image gives no colour', () async {
      expect(await dominantArgb(Uint32List(64 * 64)), isNull);
    });

    test('a cover is read in a few milliseconds', () async {
      final noisy = Uint32List(64 * 64);
      for (var i = 0; i < noisy.length; i++) {
        noisy[i] = 0xFF000000 | ((i * 2654435761) & 0xFFFFFF);
      }
      final sw = Stopwatch()..start();
      await dominantArgb(noisy);
      // Off the UI thread anyway (an isolate); this keeps it cheap there too.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  test('the chosen colour beats the cover, the cover beats the red', () {
    const aura = Color(0xFFFFC94A), cover = Color(0xFF00E5FF);
    expect(resolvePlayerTint(chosen: aura, cover: cover), aura);
    expect(resolvePlayerTint(cover: cover), cover);
    expect(resolvePlayerTint(), AppColors.accent);
  });

  group('providers', () {
    late ProviderContainer container;
    late StateController<String?> url;
    late List<String> reads;
    final known = {
      'blue.jpg': CoverColors.fromSeed(const Color(0xFF1565C0)),
      'green.jpg': CoverColors.fromSeed(const Color(0xFF2E7D32)),
    };
    final urlState = StateProvider<String?>((ref) => null);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reads = [];
      container = ProviderContainer(overrides: [
        maskProvider.overrideWith((ref) => MaskProvider()),
        currentCoverUrlProvider.overrideWith((ref) => ref.watch(urlState)),
        coverColorsReaderProvider.overrideWithValue((u) async {
          reads.add(u);
          return known[u];
        }),
      ]);
      url = container.read(urlState.notifier);
      addTearDown(container.dispose);
    });

    test('no track: the app red and the plain background', () async {
      container.listen(playerTintColorProvider, (_, _) {});
      await container.read(currentCoverColorsProvider.future);
      expect(container.read(playerTintColorProvider), AppColors.accent);
      expect(container.read(playerBackgroundColorProvider), isNull);
    });

    test('the player follows the playing cover', () async {
      container.listen(playerTintColorProvider, (_, _) {});
      container.listen(playerBackgroundColorProvider, (_, _) {});

      url.state = 'blue.jpg';
      await container.read(currentCoverColorsProvider.future);
      expect(container.read(playerTintColorProvider), known['blue.jpg']!.accent);
      expect(container.read(playerBackgroundColorProvider), known['blue.jpg']!.background);

      url.state = 'green.jpg';
      // While the next cover is read the previous colours stay.
      expect(container.read(playerTintColorProvider), known['blue.jpg']!.accent);
      await container.read(currentCoverColorsProvider.future);
      expect(container.read(playerTintColorProvider), known['green.jpg']!.accent);
    });
  });

  test('a cover is decoded once, however often it comes back', () async {
    var decodes = 0;
    final container = ProviderContainer(overrides: [
      // The real reader with its cache, minus the network.
      coverColorsReaderProvider.overrideWith((ref) {
        final reader = coverColorsCacheFor((u) async {
          decodes++;
          return CoverColors.fromSeed(const Color(0xFF1565C0));
        });
        return reader;
      }),
    ]);
    addTearDown(container.dispose);
    final read = container.read(coverColorsReaderProvider);
    await Future.wait([read('a.jpg'), read('a.jpg')]);
    await read('a.jpg');
    expect(decodes, 1);
    await read('b.jpg');
    expect(decodes, 2);
  });

  testWidgets('the tint fades to a new colour', (tester) async {
    late Color seen;
    Widget at(Color c) => AnimatedPlayerTint(
          color: c,
          child: Builder(builder: (ctx) {
            seen = PlayerTint.of(ctx);
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(at(AppColors.accent));
    expect(seen, AppColors.accent);

    await tester.pumpWidget(at(AppColors.neonCyan));
    await tester.pump(AnimatedPlayerTint.duration ~/ 2);
    expect(seen, isNot(AppColors.accent));
    expect(seen, isNot(AppColors.neonCyan));

    await tester.pumpAndSettle();
    expect(seen, AppColors.neonCyan);
  });

  test('T-02: a header asks any cover its colours; no cover, no tint', () async {
    final container = ProviderContainer(overrides: [
      coverColorsReaderProvider.overrideWithValue((url) async => CoverColors.fromSeed(const Color(0xFF2E6BFF))),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(coverColorsForProvider('').future), isNull);
    final colors = await container.read(coverColorsForProvider('https://x/cover.jpg').future);
    expect(colors, isNotNull);
    expect(colors!.background.computeLuminance(), lessThan(0.1), reason: 'white text stays legible on it');
  });
}
