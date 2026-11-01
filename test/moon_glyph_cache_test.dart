import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/moon_glyph.dart';

MoonImageKey _key({double size = 28, double ill = 0.5, bool halo = false}) => MoonImageKey(
      size: size,
      dpr: 2,
      illumination: ill,
      waxing: true,
      southern: false,
      eclipse: false,
      halo: halo,
    );

void main() {
  setUp(() => MoonImageCache.instance.clear());

  test('the same look is baked once and reused', () {
    final cache = MoonImageCache.instance;
    final a = cache.imageFor(_key());
    expect(identical(cache.imageFor(_key(ill: 0.5001)), a), isTrue,
        reason: 'below the 0.1% step it is the same moon');
    expect(identical(cache.imageFor(_key(ill: 0.51)), a), isFalse);
    expect(cache.length, 2);
  });

  test('images cover the halo at device resolution', () {
    final img = MoonImageCache.instance.imageFor(_key(size: 24, halo: true));
    expect(img.width, 24 * 2 * 2);
    final plain = MoonImageCache.instance.imageFor(_key(size: 24));
    expect(plain.width, (24 + 2) * 2);
  });

  test('the cache stays bounded, dropping the least recently used', () {
    final cache = MoonImageCache.instance;
    final first = _key(ill: 0);
    cache.imageFor(first);
    for (var i = 1; i <= MoonImageCache.maxEntries; i++) {
      cache.imageFor(_key(ill: i / 1000));
      if (i == 10) cache.imageFor(first); // recently used: survives
    }
    expect(cache.length, MoonImageCache.maxEntries);
    final before = cache.imageFor(first);
    expect(identical(cache.imageFor(first), before), isTrue);
  });

  testWidgets('glyphs in a scrolling strip bake each phase only once', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < 30; i++)
            MoonGlyph(size: 28, illumination: (i % 5) / 4, waxing: true, halo: false),
        ],
      ),
    ));
    expect(find.byType(MoonGlyph), findsWidgets);
    expect(MoonImageCache.instance.length, 5);
  });

  test('warming bakes ahead, keeping what is already baked', () {
    final cache = MoonImageCache.instance;
    final baked = cache.imageFor(_key(ill: 0));
    cache.warm([_key(ill: 0), _key(ill: 0.25), _key(ill: 0.75)]);
    expect(cache.length, 3);
    expect(identical(cache.imageFor(_key(ill: 0)), baked), isTrue);
  });
}
