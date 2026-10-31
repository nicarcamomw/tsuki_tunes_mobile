import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the beats of a song fall: its tempo plus the offset of a beat.
///
/// Times are in song (media) time, so a song sped up for Run mode keeps its
/// beats aligned without any correction.
class BeatGrid {
  final double bpm;
  /// Song time (seconds) of one beat.
  final double offset;
  /// Beat index (mod 4) that starts a bar.
  final int barShift;

  const BeatGrid(this.bpm, {this.offset = 0, this.barShift = 0});

  double get period => 60 / bpm;

  /// Beats elapsed at song time [t] (seconds); the fraction is the phase.
  double beatsAt(double t) => (t - offset) / period;

  bool isDownbeat(int beat) => (beat - barShift) % 4 == 0;

  Map<String, num> toJson() => {'b': bpm, 'o': offset, 's': barShift};

  static BeatGrid? fromJson(Object? j) {
    if (j is! Map) return null;
    final b = j['b'], o = j['o'], s = j['s'];
    if (b is! num || o is! num || b <= 0) return null;
    return BeatGrid(b.toDouble(), offset: o.toDouble(), barShift: s is num ? s.toInt() : 0);
  }
}

class BeatPulse {
  /// Pulses are folded into this range: at 170 BPM the eye beats on every
  /// other beat (half time), at 60 BPM on every half beat would be too much,
  /// so slow songs pulse once per beat.
  static const double minPulseBpm = 70, maxPulseBpm = 140;

  /// Beat length (in song beats) of one visual pulse for [bpm].
  static double pulseBeats(double bpm) {
    var beats = 1.0;
    while (bpm / beats > maxPulseBpm) {
      beats *= 2;
    }
    return beats;
  }

  /// Brightness of a pulse at [phase] (0..1 through the pulse): a quick but
  /// soft rise and an exponential fall, so it reads as a beat without a hard
  /// flash that would expose a small timing error.
  static double envelope(double phase) {
    const attack = 0.07;
    final p = phase - phase.floorToDouble();
    if (p < attack) {
      final x = p / attack;
      return x * x * (3 - 2 * x);
    }
    return exp(-(p - attack) * 5.0);
  }
}

/// Smooth playback time for animation. The player reports its position a
/// few times per second (Spotify once per second); in between this runs on
/// the wall clock at the playback speed, and drifts back gently toward each
/// report instead of jumping, unless the gap is a real seek.
class PlaybackClock {
  static const double snapAfter = 0.35; // seconds of disagreement = a seek
  static const double pull = 0.12;

  double? _t;
  Duration? _lastWall;
  Duration? _lastReported;

  double? get time => _t;

  /// [reported] is the player's position, [wall] a monotonic clock.
  double advance(Duration reported, Duration wall, {required bool playing, double rate = 1}) {
    final rep = reported.inMicroseconds / 1e6;
    final last = _lastWall;
    var t = _t;
    if (t == null || last == null) {
      t = rep;
    } else {
      if (playing) t += (wall - last).inMicroseconds / 1e6 * rate;
      if (reported != _lastReported) {
        final err = rep - t;
        t = err.abs() > snapAfter ? rep : t + err * pull;
      } else if (!playing) {
        t = rep;
      }
    }
    _lastReported = reported;
    _lastWall = wall;
    return _t = t;
  }

  void reset() {
    _t = null;
    _lastWall = null;
    _lastReported = null;
  }
}

class TapResult {
  final BeatGrid grid;
  /// The tempo came from the taps (Deezer didn't know it or disagreed).
  final bool tappedTempo;
  const TapResult(this.grid, {this.tappedTempo = false});
}

/// Turns taps on the beat into a beat grid. With a known tempo, three taps
/// fix where the beats fall; without one (or when the taps clearly disagree
/// with it), four or more taps also give the tempo.
class TapSync {
  static const Duration resetAfter = Duration(seconds: 2);
  static const int minTaps = 3;
  static const int minTapsForTempo = 4;
  /// Tap intervals within this of the beat (or two beats) agree with it.
  static const double agree = 0.15;

  final List<double> _taps = [];
  double? _lastWall;

  int get count => _taps.length;

  /// Registers a tap at song time [t] (seconds) and wall time [wall]
  /// (seconds). Returns a grid once the taps are enough to trust.
  TapResult? tap(double t, double wall, {double? bpm}) {
    final last = _lastWall;
    if (last != null && wall - last > resetAfter.inMicroseconds / 1e6) _taps.clear();
    if (_taps.isNotEmpty && t <= _taps.last) _taps.clear();
    _lastWall = wall;
    _taps.add(t);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length < minTaps) return null;

    final intervals = [for (var i = 1; i < _taps.length; i++) _taps[i] - _taps[i - 1]]..sort();
    final median = intervals[intervals.length ~/ 2];
    // Wildly uneven taps are noise.
    if (intervals.first < median * 0.6 || intervals.last > median * 1.6) return null;

    var period = bpm != null && bpm > 0 ? 60 / bpm : null;
    var tapped = false;
    if (period != null) {
      final ratio = median / period;
      // Tapping every beat or every other beat; faster taps would split
      // the phases in two, so they count as a different tempo.
      final fits = [1.0, 2.0].any((r) => (ratio / r - 1).abs() <= agree);
      if (!fits) period = null;
    }
    if (period == null) {
      if (_taps.length < minTapsForTempo) return null;
      period = _fitPeriod(_taps);
      if (period < 60 / 220 || period > 60 / 50) return null;
      tapped = true;
    }

    // Circular mean of the tap phases: the offset that best fits them all.
    var sx = 0.0, sy = 0.0;
    for (final x in _taps) {
      final a = 2 * pi * (x / period);
      sx += cos(a);
      sy += sin(a);
    }
    var phase = atan2(sy, sx) / (2 * pi);
    if (phase < 0) phase += 1;
    final offset = phase * period;
    // The first tap is taken as the start of a bar.
    final firstBeat = ((_taps.first - offset) / period).round();
    return TapResult(
      BeatGrid(60 / period, offset: offset, barShift: firstBeat % 4),
      tappedTempo: tapped,
    );
  }

  void clear() {
    _taps.clear();
    _lastWall = null;
  }

  /// Least-squares slope of tap time against tap number.
  static double _fitPeriod(List<double> taps) {
    final n = taps.length;
    final mx = (n - 1) / 2;
    final my = taps.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (i - mx) * (taps[i] - my);
      den += (i - mx) * (i - mx);
    }
    return num / den;
  }
}

/// Beat grids set by tapping, remembered per song and source (a preview is a
/// different excerpt than the full song on Spotify).
class BeatSyncStore {
  static final BeatSyncStore shared = BeatSyncStore();
  static const _key = 'beat_sync_v1';
  static const int maxEntries = 300;

  final Map<String, BeatGrid> _grids = {};
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
        final g = BeatGrid.fromJson(v);
        if (g != null) _grids[k] = g;
      });
    } catch (e) {
      debugPrint('[BeatSync] load error: $e');
    }
  }

  static String keyFor(String trackId, {required bool fullSong}) =>
      '$trackId:${fullSong ? 'full' : 'preview'}';

  BeatGrid? get(String key) => _grids[key];

  Future<void> put(String key, BeatGrid grid) async {
    _grids.remove(key);
    _grids[key] = grid;
    while (_grids.length > maxEntries) {
      _grids.remove(_grids.keys.first);
    }
    await _save();
  }

  Future<void> remove(String key) async {
    if (_grids.remove(key) != null) await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode({for (final e in _grids.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }
}
