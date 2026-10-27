import 'dart:math';

import '../models/track.dart';

/// How a song's tempo lines up with a step cadence.
class PaceMatch {
  final double bpm;
  /// 1 = one step per beat; 2 = two steps per beat (a half-time song while
  /// running); 0.5 = one step every two beats (a fast song while walking).
  final double stepsPerBeat;
  final double cadence;

  const PaceMatch(this.bpm, this.stepsPerBeat, this.cadence);

  /// The song's tempo counted in steps per minute.
  double get beat => bpm * stepsPerBeat;

  /// Playback speed that would put the beat exactly on the steps.
  double get exactRate => cadence / beat;

  /// How far off the song is, as a fraction (0.03 = 3%).
  double get deviation => (exactRate - 1).abs();
}

class PaceMatcher {
  /// Songs within this of the cadence count as a match.
  static const double tolerance = 0.06;
  /// Furthest the playback speed is stretched to lock onto the steps. Up to
  /// ~8% the time-stretch keeps the voice natural.
  static const double maxStretch = 0.08;
  /// Off by more than this for [driftPatience], a full-length song is cut
  /// short for one at the new pace.
  static const double driftLimit = 0.12;
  static const Duration driftPatience = Duration(seconds: 20);

  static PaceMatch match(double bpm, double cadence) {
    PaceMatch? best;
    for (final steps in _ratiosFor(cadence)) {
      final m = PaceMatch(bpm, steps, cadence);
      if (best == null || _cost(m) < _cost(best)) best = m;
    }
    return best!;
  }

  /// Half-time songs only make sense running, double-time only walking.
  static List<double> _ratiosFor(double cadence) => [
        1,
        if (cadence >= 140) 2,
        if (cadence <= 125) 0.5,
      ];

  // Log distance, so 5% faster and 5% slower weigh the same.
  static double _cost(PaceMatch m) =>
      log(m.exactRate).abs() + (m.stepsPerBeat == 1 ? 0 : 0.015);

  /// Playback speed for a song at [bpm] under [cadence], within the stretch
  /// limit. Songs too far off play at their own speed.
  static double playbackRate(double bpm, double cadence) {
    final m = match(bpm, cadence);
    if (m.deviation > tolerance + maxStretch) return 1.0;
    return m.exactRate.clamp(1 - maxStretch, 1 + maxStretch);
  }

  /// Song tempos (in BPM) worth searching for at [cadence].
  static List<double> targetTempos(double cadence) =>
      [for (final r in _ratiosFor(cadence)) cadence / r];

  /// Picks the next song for [cadence] from [candidates] with known [bpms].
  /// Closer tempos win, favourites get a nudge, the same artist twice in a
  /// row is avoided, and a little randomness keeps sessions from repeating.
  static Track? pick(
    Iterable<Track> candidates,
    Map<String, double> bpms,
    double cadence, {
    Set<String> avoid = const {},
    String? lastArtistId,
    Set<String> favorites = const {},
    Random? random,
  }) {
    final rng = random ?? Random();
    Track? best;
    var bestScore = double.infinity;
    for (final t in candidates) {
      if (avoid.contains(t.id)) continue;
      final bpm = bpms[t.id];
      if (bpm == null || bpm <= 0) continue;
      final m = match(bpm, cadence);
      if (m.deviation > tolerance) continue;
      var score = m.deviation / tolerance;
      if (m.stepsPerBeat != 1) score += 0.3;
      if (lastArtistId != null && t.artistId == lastArtistId) score += 0.8;
      if (favorites.contains(t.id)) score -= 0.35;
      score += rng.nextDouble() * 0.5;
      if (score < bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return best;
  }
}
