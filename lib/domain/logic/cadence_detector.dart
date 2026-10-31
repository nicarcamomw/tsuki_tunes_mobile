import 'dart:math';

enum MotionState { still, walking, running }

class CadenceReading {
  /// Steps per minute, smoothed. Null while the motion has no clear rhythm.
  final double? spm;
  /// How periodic the motion is, 0..1.
  final double confidence;
  final MotionState state;

  const CadenceReading({this.spm, this.confidence = 0, this.state = MotionState.still});

  static const none = CadenceReading();
}

/// Turns raw accelerometer samples into steps per minute.
///
/// Instead of counting peaks (which double-count bouncy steps and miss soft
/// ones), it looks for the period at which the motion repeats: the
/// autocorrelation of the last few seconds of acceleration. That works the
/// same in a hand, a pocket or an armband, whatever the phone's orientation,
/// because it only uses the magnitude of the acceleration.
class CadenceDetector {
  /// Samples are resampled to this fixed rate before analysis.
  static const double rate = 50;
  static const Duration window = Duration(seconds: 8);
  /// Enough data for at least a few strides before the first estimate.
  static const Duration minData = Duration(seconds: 4);
  static const double minSpm = 50;
  static const double maxSpm = 230;
  /// Below this (m/s², standard deviation) the phone is resting or barely
  /// moving: no steps.
  static const double stillEnergy = 0.45;
  static const double minConfidence = 0.3;
  static const double minProminence = 0.5;
  /// Walking rarely goes past this; faster needs running impacts.
  static const double maxWalkingSpm = 150;
  /// Typical impact energy (m/s², standard deviation) of running.
  static const double runningEnergy = 3.0;
  /// Impact energy only running produces (about 0.5 g of spread).
  static const double strideEnergy = 5.0;
  /// Cadence at which walking turns into running.
  static const double runningSpm = 140;
  /// Longer sensor silences reset the analysis (the stream was paused).
  static const Duration maxGap = Duration(milliseconds: 600);

  final int _capacity = (rate * window.inMilliseconds / 1000).round();
  final List<double> _buf = [];
  Duration? _lastT;
  double _lastM = 0;
  Duration _nextGrid = Duration.zero;
  final List<double> _recent = [];

  static const Duration _step = Duration(microseconds: 20000); // 1 / rate

  void reset() {
    _buf.clear();
    _recent.clear();
    _lastT = null;
  }

  /// Adds one accelerometer sample taken at [t] (any monotonic clock).
  void add(double x, double y, double z, Duration t) {
    final m = sqrt(x * x + y * y + z * z);
    final last = _lastT;
    if (last == null || t - last > maxGap || t < last) {
      if (last != null) reset();
      _lastT = t;
      _lastM = m;
      _buf.add(m);
      _nextGrid = t + _step;
      return;
    }
    // Linear interpolation onto the fixed grid.
    final span = (t - last).inMicroseconds;
    while (_nextGrid <= t) {
      final f = span == 0 ? 1.0 : (_nextGrid - last).inMicroseconds / span;
      _buf.add(_lastM + (m - _lastM) * f);
      _nextGrid += _step;
    }
    if (_buf.length > _capacity) _buf.removeRange(0, _buf.length - _capacity);
    _lastT = t;
    _lastM = m;
  }

  Duration get bufferedTime => Duration(microseconds: (_buf.length * 1e6 / rate).round());

  /// Raw estimate from the current window, without smoothing.
  CadenceReading analyze() {
    final n = _buf.length;
    if (n < rate * minData.inMilliseconds / 1000) return CadenceReading.none;

    // Remove gravity (the window mean) and smooth over 3 samples.
    final mean = _buf.reduce((a, b) => a + b) / n;
    final x = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final a = _buf[max(0, i - 1)], b = _buf[i], c = _buf[min(n - 1, i + 1)];
      x[i] = (a + b + c) / 3 - mean;
    }
    var energy = 0.0;
    for (final v in x) {
      energy += v * v;
    }
    final std = sqrt(energy / n);
    if (std < stillEnergy) return CadenceReading.none;

    // Lags covering one step at maxSpm up to one stride (two steps) at minSpm.
    final minLag = (60 * rate / maxSpm).floor();
    final maxLag = min(n ~/ 2, (2 * 60 * rate / minSpm).ceil());
    final r = List<double>.filled(maxLag + 2, 0);
    for (var k = 1; k <= maxLag + 1 && k < n; k++) {
      r[k] = _corr(x, k);
    }

    // Strongest local maximum.
    var best = -1;
    for (var k = minLag; k <= maxLag; k++) {
      if (r[k] > r[k - 1] && r[k] >= r[k + 1] && (best < 0 || r[k] > r[best])) best = k;
    }
    if (best < 0 || r[best] < minConfidence) {
      return CadenceReading(confidence: max(0, best < 0 ? 0 : r[best]));
    }
    // A real rhythm swings: the correlation drops well below the peak
    // between repetitions. Slow drifts (turning the phone in a hand) decay
    // smoothly with small bumps instead.
    final valley = r.sublist(1, best).reduce(min);
    if (r[best] - valley < minProminence) return CadenceReading(confidence: r[best]);

    // The strongest repetition is often a stride (left + right foot, which
    // differ when the phone is in a pocket) or a few steps. If the period
    // splits evenly into peaks (every one of them clear), those are the
    // steps. A heel strike can add a half-period peak too, so very fast
    // cadences are only accepted with the impact energy of running.
    final maxPlausible = std > runningEnergy ? maxSpm : maxWalkingSpm;
    final floor = 0.45 * r[best];
    var k = best;
    while (true) {
      int? next;
      for (final parts in const [5, 4, 3, 2]) {
        final cand = _peakNear(r, k / parts, minLag);
        if (cand == null || r[cand] < floor || 60 * rate / cand > maxPlausible) continue;
        var even = true;
        for (var m = 2; m < parts && even; m++) {
          final p = _peakNear(r, k * m / parts, minLag);
          even = p != null && r[p] >= floor;
        }
        if (even) {
          next = cand;
          break;
        }
      }
      if (next == null || next == k) break;
      k = next;
    }
    var lag = _refine(r, k);
    // Nobody walks rhythmically under ~75 steps/min, and nobody lands with
    // running impacts under ~115: that is a stride whose step peak is
    // buried (one foot barely registers with the phone in a pocket).
    final rawSpm = 60 * rate / lag;
    if (rawSpm < 75 || (std > strideEnergy && rawSpm < 115)) lag /= 2;

    final spm = 60 * rate / lag;
    if (spm < minSpm || spm > maxSpm) return CadenceReading(confidence: r[best]);
    return CadenceReading(
      spm: spm,
      confidence: r[best].clamp(0.0, 1.0),
      state: spm >= runningSpm ? MotionState.running : MotionState.walking,
    );
  }

  /// Smoothed reading: the median of the last few raw estimates, so one odd
  /// window (a stumble, stopping at a crossing) doesn't move the music.
  CadenceReading update() {
    final raw = analyze();
    if (raw.spm == null) {
      _recent.clear();
      return raw;
    }
    _recent.add(raw.spm!);
    if (_recent.length > 5) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    final median = sorted[sorted.length ~/ 2];
    return CadenceReading(
      spm: median,
      confidence: raw.confidence,
      state: median >= runningSpm ? MotionState.running : MotionState.walking,
    );
  }

  static double _corr(List<double> x, int k) {
    var num = 0.0, a = 0.0, b = 0.0;
    for (var i = 0; i + k < x.length; i++) {
      num += x[i] * x[i + k];
      a += x[i] * x[i];
      b += x[i + k] * x[i + k];
    }
    final d = sqrt(a * b);
    return d == 0 ? 0 : num / d;
  }

  /// Local maximum of [r] within ±12% of [lag].
  static int? _peakNear(List<double> r, double lag, int minLag) {
    final lo = max(minLag, (lag * 0.88).floor());
    final hi = min(r.length - 2, (lag * 1.12).ceil());
    int? best;
    for (var k = lo; k <= hi; k++) {
      if (k < 1) continue;
      if (r[k] > r[k - 1] && r[k] >= r[k + 1] && (best == null || r[k] > r[best])) best = k;
    }
    return best;
  }

  /// Sub-sample peak position by fitting a parabola through three points.
  static double _refine(List<double> r, int k) {
    if (k < 1 || k + 1 >= r.length) return k.toDouble();
    final a = r[k - 1], b = r[k], c = r[k + 1];
    final d = a - 2 * b + c;
    if (d == 0) return k.toDouble();
    return k + (0.5 * (a - c) / d).clamp(-0.5, 0.5);
  }
}
