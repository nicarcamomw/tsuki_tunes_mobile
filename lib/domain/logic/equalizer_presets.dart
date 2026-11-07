import 'dart:math' as math;

/// The equalizer's presets. They apply to what Tsuki plays itself (Deezer's
/// previews); a song playing in Spotify comes out of Spotify's own app.
enum EqPreset { off, bass, rock, pop, vocal, electronic, acoustic, night }

/// The gain of each preset along the frequencies, as points (Hz, dB) joined
/// on a log scale: every phone has its own bands, so a preset is a curve and
/// each band takes the gain at its centre.
abstract final class EqCurves {
  static const Map<EqPreset, List<(double, double)>> points = {
    EqPreset.off: [(20, 0), (20000, 0)],
    // Deep lows up, a touch of mids out of their way.
    EqPreset.bass: [(30, 6), (60, 6), (150, 4), (400, 0), (1000, -1), (4000, 0), (16000, 0)],
    // The classic smile: lows and highs up, the middle a little down.
    EqPreset.rock: [(60, 4.5), (150, 3), (400, -1), (1000, -1.5), (2500, 1), (6000, 3.5), (14000, 4)],
    // Presence and air for voices and synths, a light low end.
    EqPreset.pop: [(60, 1.5), (150, 2.5), (400, 1), (1000, 0), (2500, 2), (6000, 3), (14000, 2)],
    // The voice forward: low-mids and lows back, presence up.
    EqPreset.vocal: [(60, -2), (150, -1.5), (400, 1), (1000, 3), (2500, 4), (6000, 2), (14000, 0)],
    // Sub and kick up, the mids clean, sparkle on top.
    EqPreset.electronic: [(40, 5), (90, 4.5), (250, 0.5), (1000, -1), (3000, 1), (8000, 3.5), (15000, 4)],
    // Warm and natural: body in the low-mids, soft highs.
    EqPreset.acoustic: [(60, 1), (200, 2.5), (600, 1.5), (1500, 0.5), (4000, 2), (10000, 1.5), (16000, 0.5)],
    // Late at night: deep lows and sharp highs down, nothing that startles.
    EqPreset.night: [(40, -3), (100, -1), (300, 0.5), (1000, 1), (3000, 0), (8000, -3), (16000, -5)],
  };

  /// The gain (dB) of [preset] at [hz], within [min]..[max] (what the
  /// phone's equalizer allows).
  static double gainAt(EqPreset preset, double hz, {double min = -15, double max = 15}) {
    final p = points[preset]!;
    double g;
    if (hz <= p.first.$1) {
      g = p.first.$2;
    } else if (hz >= p.last.$1) {
      g = p.last.$2;
    } else {
      g = p.last.$2;
      for (var i = 0; i < p.length - 1; i++) {
        final (f0, g0) = p[i];
        final (f1, g1) = p[i + 1];
        if (hz >= f0 && hz <= f1) {
          final t = (math.log(hz) - math.log(f0)) / (math.log(f1) - math.log(f0));
          g = g0 + (g1 - g0) * t;
          break;
        }
      }
    }
    return g.clamp(min, max).toDouble();
  }

  static EqPreset fromName(String? name) =>
      EqPreset.values.firstWhere((p) => p.name == name, orElse: () => EqPreset.off);
}
