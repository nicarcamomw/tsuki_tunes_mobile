import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../core/constants/app_colors.dart';
import '../../core/logger.dart';
import '../widgets/oni_mask_colors.dart';
import 'app_providers.dart';

final _log = Log.named('CoverColors');

/// The colours taken from a track's cover: an [accent] bright enough to read
/// on the dark player, and a deep [background] for the player's gradient.
@immutable
class CoverColors {
  final Color accent;
  final Color background;

  const CoverColors({required this.accent, required this.background});

  /// Builds both colours from the cover's [seed], keeping the cyberpunk
  /// look: the accent is lifted to a lightness that reads on [AppColors.bgDeep],
  /// the background pushed down near it so white text stays legible.
  /// A grey cover (no real hue) gives null: the player keeps its own colour.
  static CoverColors? fromSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    if (hsl.saturation < minSaturation) return null;
    final accent = hsl
        .withSaturation(hsl.saturation.clamp(0.55, 1.0))
        .withLightness(hsl.lightness.clamp(0.55, 0.72))
        .toColor();
    final background = hsl
        .withSaturation((hsl.saturation * 0.7).clamp(0.25, 0.6))
        .withLightness(0.16)
        .toColor();
    return CoverColors(accent: accent, background: background);
  }

  /// Below this saturation a cover is treated as black, white or grey.
  static const double minSaturation = 0.12;

  @override
  bool operator ==(Object other) =>
      other is CoverColors && other.accent == accent && other.background == background;

  @override
  int get hashCode => Object.hash(accent, background);
}

/// Reads the colours of the cover at a URL; null when it has none or fails.
typedef CoverColorsReader = Future<CoverColors?> Function(String coverUrl);

/// Side of the copy of the cover its colour is read from: plenty for a
/// dominant colour, and 4 096 pixels instead of the cover's up to a million.
const coverSampleSize = 64;

/// Picks the cover's most representative colour with Material's quantizer
/// and scoring (as dynamic colour on Android does) and adapts it.
///
/// Nothing heavy runs on the UI thread, so a song change never stutters the
/// screen: the engine decodes the cover straight at [coverSampleSize] (it's
/// on disk already, the player shows it), and the quantizing, which took
/// 40 to 170 ms through ColorScheme.fromImageProvider, runs in an isolate.
Future<CoverColors?> readCoverColors(String coverUrl) async {
  try {
    final pixels = await _samplePixels(ResizeImage(
      CachedNetworkImageProvider(coverUrl),
      width: coverSampleSize,
      height: coverSampleSize,
    ));
    if (pixels == null) return null;
    final seed = await Isolate.run(() => dominantArgb(pixels));
    return seed == null ? null : CoverColors.fromSeed(Color(seed));
  } catch (e) {
    _log.fine('No colours for $coverUrl: $e');
    return null;
  }
}

/// The pixels of [provider]'s image, as ARGB.
Future<Uint32List?> _samplePixels(ImageProvider provider) async {
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener((info, _) {
    stream.removeListener(listener);
    // Our own handle: the cache may let go of its image once we stop
    // listening, before its pixels are read.
    if (!completer.isCompleted) completer.complete(info.image.clone());
  }, onError: (Object e, StackTrace? st) {
    stream.removeListener(listener);
    if (!completer.isCompleted) completer.completeError(e, st);
  });
  stream.addListener(listener);
  final image = await completer.future.timeout(const Duration(seconds: 10));
  try {
    final data = await image.toByteData(); // RGBA bytes
    if (data == null) return null;
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final out = Uint32List(rgba.length ~/ 4);
    for (var i = 0, p = 0; i < out.length; i++, p += 4) {
      out[i] = rgba[p + 3] << 24 | rgba[p] << 16 | rgba[p + 1] << 8 | rgba[p + 2];
    }
    return out;
  } finally {
    image.dispose();
  }
}

/// The most representative colour of [argbPixels] (Celebi quantizer, then
/// Material's score, which favours vivid colours that cover a fair share),
/// or null for an image with no pixels to speak of. Pure Dart: it runs in
/// an isolate.
@visibleForTesting
Future<int?> dominantArgb(Uint32List argbPixels) async {
  final opaque = [
    for (final p in argbPixels)
      if ((p >> 24) >= 0xF0) p
  ];
  if (opaque.isEmpty) return null;
  final result = await QuantizerCelebi().quantize(opaque, 128);
  if (result.colorToCount.isEmpty) return null;
  // No colour good enough (a black and white cover): none, not the
  // scorer's default blue, so the player keeps its own colour.
  final best = Score.score(result.colorToCount, desired: 1, fallbackColorARGB: 0).first;
  return best == 0 ? null : best;
}

/// How covers are read; overridden in tests.
final coverColorsReaderProvider = Provider<CoverColorsReader>((ref) => coverColorsCacheFor(readCoverColors));

/// [read] behind a cache of the last covers: going back and forth in the
/// queue doesn't decode the same image again, and a cover asked twice while
/// it's being read is read once.
CoverColorsReader coverColorsCacheFor(CoverColorsReader read) {
  final cache = _CoverColorsCache();
  return (url) => cache.get(url, read);
}

/// The playing track's cover.
final currentCoverUrlProvider =
    Provider<String?>((ref) => ref.watch(audioProvider.select((a) => a.currentTrack?.coverUrl)));

/// The colours of the playing track's cover. While the next cover is read
/// the previous colours stay (Riverpod keeps the last value on reload), so
/// the player fades from one track to the next instead of flashing red.
final currentCoverColorsProvider = FutureProvider<CoverColors?>((ref) async {
  final url = ref.watch(currentCoverUrlProvider);
  if (url == null || url.isEmpty) return null;
  return ref.read(coverColorsReaderProvider)(url);
});

/// The player's accent: a UL or DS mask's aura, else the colour the user
/// chose in the levels, else the cover's colour, else the app's red.
final playerTintColorProvider = Provider<Color>((ref) {
  final chosen = ref.watch(maskProvider.select((m) =>
      m.equipped?.playerAura ?? (m.playerColor == null ? null : Color(m.playerColor!.argb))));
  return resolvePlayerTint(
    chosen: chosen,
    cover: chosen != null ? null : ref.watch(currentCoverColorsProvider.select((c) => c.value?.accent)),
  );
});

/// What the user picked (a mask's aura or a level colour) wins over the
/// cover, and the cover over the app's red.
Color resolvePlayerTint({Color? chosen, Color? cover}) => chosen ?? cover ?? AppColors.accent;

/// The player's background tint from the cover, or null for the plain one.
final playerBackgroundColorProvider = Provider<Color?>(
    (ref) => ref.watch(currentCoverColorsProvider.select((c) => c.value?.background)));

/// The colours of the last [_capacity] covers, least recently used first.
class _CoverColorsCache {
  static const _capacity = 64;
  final _done = <String, CoverColors?>{}; // insertion-ordered
  final _pending = <String, Future<CoverColors?>>{};

  Future<CoverColors?> get(String url, CoverColorsReader read) {
    if (_done.containsKey(url)) {
      final hit = _done.remove(url);
      _done[url] = hit; // most recent last
      return Future.value(hit);
    }
    return _pending[url] ??= read(url).then((colors) {
      _pending.remove(url);
      _done[url] = colors;
      if (_done.length > _capacity) _done.remove(_done.keys.first);
      return colors;
    });
  }
}

/// Any cover's colours (T-02: the album and playlist headers), through the
/// same cache as the player's. Null for an empty URL or a grey cover.
final coverColorsForProvider = FutureProvider.family<CoverColors?, String>((ref, url) async {
  if (url.isEmpty) return null;
  return ref.read(coverColorsReaderProvider)(url);
});
