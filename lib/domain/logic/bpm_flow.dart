import 'dart:math';

import '../entities/track.dart';

enum FlowMode {
  /// Tempo climbs gradually: warm-up, workout, party.
  rise,
  /// Tempo winds down: evening, studying, sleep.
  calm,
  /// Builds to a peak about two thirds in, then cools down, like a DJ set.
  wave,
}

class FlowResult {
  final List<Track> order;
  final int known;
  final int total;
  final double? fromBpm;
  final double? peakBpm;
  final double? toBpm;

  const FlowResult({
    required this.order,
    required this.known,
    required this.total,
    this.fromBpm,
    this.peakBpm,
    this.toBpm,
  });

  double get coverage => total == 0 ? 0 : known / total;
}

/// Orders a queue by tempo.
class BpmFlow {
  /// Below this share of known tempos the result is mostly guesswork.
  static const double minUsefulCoverage = 0.4;

  /// Folds half and double time into one octave, so a 70 BPM ballad and a
  /// 140 BPM track count as the same feel, the way DJs pair them.
  static double feel(double bpm) {
    var b = bpm;
    while (b < 85) {
      b *= 2;
    }
    while (b >= 170) {
      b /= 2;
    }
    return b;
  }

  /// Reorders [tracks]. Tracks without a known tempo keep their exact
  /// positions; the others fill the remaining slots in flow order. Ties keep
  /// their original order, so runs from the same album stay together.
  static FlowResult arrange(
    List<Track> tracks,
    Map<String, double> bpms,
    FlowMode mode,
  ) {
    final knownSlots = <int>[];
    final known = <(int, Track, double)>[];
    for (var i = 0; i < tracks.length; i++) {
      final bpm = bpms[tracks[i].id];
      if (bpm != null && bpm > 0) {
        knownSlots.add(i);
        known.add((i, tracks[i], feel(bpm)));
      }
    }

    final ascending = [...known]..sort((a, b) {
        final c = a.$3.compareTo(b.$3);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });

    final List<(int, Track, double)> ordered;
    switch (mode) {
      case FlowMode.rise:
        ordered = ascending;
      case FlowMode.calm:
        ordered = ascending.reversed.toList();
      case FlowMode.wave:
        // Two of every three steps go into the climb, the rest into the
        // cool-down (played in reverse), so the peak lands ~2/3 through.
        final up = <(int, Track, double)>[];
        final down = <(int, Track, double)>[];
        for (var i = 0; i < ascending.length; i++) {
          (i % 3 == 2 ? down : up).add(ascending[i]);
        }
        ordered = [...up, ...down.reversed];
    }

    final result = [...tracks];
    for (var i = 0; i < knownSlots.length; i++) {
      result[knownSlots[i]] = ordered[i].$2;
    }

    return FlowResult(
      order: result,
      known: known.length,
      total: tracks.length,
      fromBpm: ordered.isEmpty ? null : ordered.first.$3,
      peakBpm: ordered.isEmpty ? null : ordered.map((e) => e.$3).reduce(max),
      toBpm: ordered.isEmpty ? null : ordered.last.$3,
    );
  }
}

/// Turns Deezer's loudness into a playback volume for previews.
///
/// Deezer's `gain` is a loudness in dB where higher is louder; tools that
/// convert it to ReplayGain use `-(gain + 18.4)`. The player can only lower
/// the volume, so songs louder than [targetGain] are brought down to it
/// (never more than [maxCutDb]) and quieter ones play at full volume.
class Loudness {
  /// About ReplayGain -6.4 dB: typical modern masters get a light trim,
  /// very loud ones a clear one, quiet recordings none.
  static const double targetGain = -12.0;
  static const double maxCutDb = 9.0;

  static double factorFor(double? gain) {
    if (gain == null) return 1.0;
    final cut = (gain - targetGain).clamp(0.0, maxCutDb);
    return pow(10, -cut / 20).toDouble();
  }
}
