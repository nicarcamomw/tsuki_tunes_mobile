import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Picks the cover's most representative colour with Material's quantizer
/// (the same scoring as dynamic colour on Android) and adapts it.
Future<CoverColors?> readCoverColors(String coverUrl) async {
  try {
    final scheme = await ColorScheme.fromImageProvider(
      provider: CachedNetworkImageProvider(coverUrl),
      brightness: Brightness.dark,
      // Fidelity keeps the primary close to the cover's real colour.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return CoverColors.fromSeed(scheme.primary);
  } catch (e) {
    _log.fine('No colours for $coverUrl: $e');
    return null;
  }
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
