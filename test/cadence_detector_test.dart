import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/logic/cadence_detector.dart';

const _g = 9.81;

/// Simulated accelerometer for someone stepping at [spm]. Each step is a
/// heel-strike bump; [asymmetry] makes every other step weaker (phone in one
/// pocket); [jitter] varies each step's timing; [impact] is the bump size in
/// m/s² (walking ~3, running ~35).
class _Gait {
  final double spm;
  final double asymmetry;
  final double jitter;
  final double impact;
  final double noise;
  final Random rng;
  final List<double> _stepTimes = [];

  _Gait(this.spm,
      {this.asymmetry = 0, this.jitter = 0.03, this.impact = 3, this.noise = 0.3, int seed = 1})
      : rng = Random(seed) {
    var t = 0.0;
    while (t < 120) {
      _stepTimes.add(t);
      t += 60 / spm * (1 + (rng.nextDouble() * 2 - 1) * jitter);
    }
  }

  double vertical(double t) {
    var a = 0.0;
    for (var i = 0; i < _stepTimes.length; i++) {
      final d = t - _stepTimes[i];
      if (d < -0.3) break;
      if (d > 0.5) continue;
      final amp = impact * (i.isEven ? 1 : 1 - asymmetry);
      // Sharp impact, a softer push-off and the flight/swing phase, all
      // scaled to the step period (at 120 steps/min: 0, 0.15 s, 0.3 s).
      final p = 60 / spm / 0.5;
      a += amp * exp(-pow(d / (0.04 * p), 2)) +
          0.4 * amp * exp(-pow((d - 0.15 * p) / (0.07 * p), 2));
      a -= 0.35 * amp * exp(-pow((d - 0.3 * p) / (0.1 * p), 2));
    }
    return a + (rng.nextDouble() * 2 - 1) * noise;
  }
}

/// Feeds [seconds] of [signal] at roughly [hz] (with timing jitter), with
/// gravity along a tilted axis like a phone in a pocket.
CadenceReading _run(CadenceDetector d, double Function(double t) signal,
    {double seconds = 10, double hz = 50, double start = 0, int seed = 2}) {
  final rng = Random(seed);
  var t = start;
  CadenceReading last = CadenceReading.none;
  var nextUpdate = start + 0.5;
  while (t < start + seconds) {
    final v = signal(t);
    // Gravity + vertical motion mostly along y, some on x and z.
    d.add(0.3 * (_g + v), 0.85 * (_g + v), 0.43 * (_g + v) + 0.2 * sin(t * 3),
        Duration(microseconds: (t * 1e6).round()));
    if (t >= nextUpdate) {
      last = d.update();
      nextUpdate += 0.5;
    }
    t += 1 / hz * (1 + (rng.nextDouble() * 2 - 1) * 0.2);
  }
  return last;
}

void main() {
  group('cadence', () {
    for (final spm in [90.0, 105.0, 120.0, 135.0]) {
      test('walking at $spm steps/min, phone in hand', () {
        final g = _Gait(spm, impact: 3);
        final r = _run(CadenceDetector(), g.vertical);
        expect(r.spm, closeTo(spm, spm * 0.03));
        expect(r.state, MotionState.walking);
      });

      test('walking at $spm steps/min, phone in a pocket (uneven steps)', () {
        final g = _Gait(spm, impact: 3, asymmetry: 0.5, seed: 7);
        final r = _run(CadenceDetector(), g.vertical);
        expect(r.spm, closeTo(spm, spm * 0.03));
      });
    }

    for (final spm in [150.0, 165.0, 180.0, 195.0]) {
      test('running at $spm steps/min', () {
        final g = _Gait(spm, impact: 35, asymmetry: 0.3, noise: 2, seed: spm.toInt());
        final r = _run(CadenceDetector(), g.vertical);
        expect(r.spm, closeTo(spm, spm * 0.03));
        expect(r.state, MotionState.running);
      });
    }

    test('accurate across hundreds of simulated walkers and runners', () {
      var misses = 0, total = 0;
      for (var spm = 80.0; spm <= 200; spm += 5) {
        for (var seed = 1; seed <= 4; seed++) {
          for (final asym in [0.0, 0.4, 0.7]) {
            final running = spm >= 145;
            final g = _Gait(spm,
                impact: running ? 30.0 + seed * 5 : 1.5 + seed * 0.5,
                asymmetry: asym,
                jitter: 0.03 + seed * 0.01,
                noise: running ? 2 : 0.6,
                seed: seed * 31 + spm.toInt());
            final r = _run(CadenceDetector(), g.vertical, seed: seed);
            total++;
            if (r.spm == null || (r.spm! - spm).abs() > spm * 0.04) misses++;
          }
        }
      }
      expect(misses / total, lessThanOrEqualTo(0.02), reason: '$misses of $total missed');
    });

    test('works with a 100 Hz sensor too', () {
      final g = _Gait(118, impact: 3, asymmetry: 0.4);
      final r = _run(CadenceDetector(), g.vertical, hz: 100);
      expect(r.spm, closeTo(118, 3.5));
    });

    test('a phone lying still reports no steps', () {
      final rng = Random(3);
      final r = _run(CadenceDetector(), (_) => (rng.nextDouble() * 2 - 1) * 0.08);
      expect(r.spm, isNull);
      expect(r.state, MotionState.still);
    });

    test('random handling is not mistaken for steps', () {
      final rng = Random(4);
      var drift = 0.0;
      final r = _run(CadenceDetector(), (_) {
        drift += (rng.nextDouble() * 2 - 1) * 0.8;
        drift *= 0.97;
        return drift + (rng.nextDouble() * 2 - 1) * 1.5;
      });
      expect(r.spm, isNull);
    });

    test('a single bump does not create a cadence', () {
      final r = _run(CadenceDetector(), (t) => (t - 5).abs() < 0.1 ? 25 : 0);
      expect(r.spm, isNull);
    });

    test('follows a change of pace within a few seconds', () {
      final d = CadenceDetector();
      final walk = _Gait(110, impact: 3);
      _run(d, walk.vertical, seconds: 12);
      final run = _Gait(165, impact: 35, noise: 2);
      final r = _run(d, (t) => run.vertical(t - 12), start: 12, seconds: 8);
      expect(r.spm, closeTo(165, 5));
    });

    test('needs a few seconds of data before the first estimate', () {
      final d = CadenceDetector();
      final g = _Gait(120);
      final r = _run(d, g.vertical, seconds: 3);
      expect(r.spm, isNull);
    });

    test('a long sensor gap starts over instead of mixing old and new data', () {
      final d = CadenceDetector();
      final g = _Gait(120);
      _run(d, g.vertical, seconds: 10);
      expect(d.bufferedTime.inSeconds, greaterThanOrEqualTo(7));
      d.add(0, _g, 0, const Duration(seconds: 30));
      expect(d.bufferedTime.inMilliseconds, lessThan(100));
    });
  });
}
