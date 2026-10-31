import 'dart:math';
import 'dart:typed_data';

enum AmbientSound { rain, storm, waves, fire, wind, night, brownNoise }

/// Synthesizes seamless ambient loops as 16-bit mono WAV bytes.
///
/// Everything is generated procedurally, so there are no bundled assets and no
/// licensing to track. Each sound uses a fixed seed: the same sound always
/// produces the same bytes, which keeps the on-disk cache valid.
class AmbientSoundGenerator {
  static const int sampleRate = 22050;
  static const int _fadeSamples = sampleRate * 2;

  static int loopSeconds(AmbientSound sound) => switch (sound) {
        AmbientSound.rain => 30,
        AmbientSound.storm => 48,
        AmbientSound.waves => 32,
        AmbientSound.fire => 30,
        AmbientSound.wind => 36,
        AmbientSound.night => 30,
        AmbientSound.brownNoise => 20,
      };

  /// Top-level entry point so it can run inside an isolate.
  static Uint8List generateWav(AmbientSound sound) =>
      encodeWav(generateSamples(sound));

  static Float64List generateSamples(AmbientSound sound) {
    final n = loopSeconds(sound) * sampleRate;
    // Render past the loop end, then blend that tail into the start so the
    // last sample flows straight into the first one.
    final raw = Float64List(n + _fadeSamples);
    final rng = Random(sound.index * 7919 + 17);
    switch (sound) {
      case AmbientSound.rain:
        _rain(raw, rng, heavy: false);
      case AmbientSound.storm:
        _rain(raw, rng, heavy: true);
        _thunder(raw, rng, n);
      case AmbientSound.waves:
        _waves(raw, rng, n);
      case AmbientSound.fire:
        _fire(raw, rng);
      case AmbientSound.wind:
        _wind(raw, rng, n);
      case AmbientSound.night:
        _night(raw, rng);
      case AmbientSound.brownNoise:
        _brown(raw, rng);
    }
    final out = _makeSeamless(raw, n);
    // Short drops and crackles can be squashed without sounding distorted;
    // tonal crickets and thunder rumble can't.
    _normalize(out, peakLimit: switch (sound) {
      AmbientSound.night => 1.1,
      AmbientSound.storm => 1.4,
      _ => 3.0,
    });
    return out;
  }

  static Float64List _makeSeamless(Float64List raw, int n) {
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = raw[i];
    }
    // Equal-power blend: at i = 0 the output is exactly raw[n], the sample
    // that naturally follows raw[n - 1].
    for (var i = 0; i < _fadeSamples; i++) {
      final t = i / _fadeSamples;
      out[i] = raw[i] * sin(t * pi / 2) + raw[n + i] * cos(t * pi / 2);
    }
    return out;
  }

  static void _normalize(Float64List s, {required double peakLimit}) {
    var sum = 0.0;
    var peak = 0.0;
    for (final v in s) {
      sum += v * v;
      peak = max(peak, v.abs());
    }
    final rms = sqrt(sum / s.length);
    if (rms == 0) return;
    // Aim for a common loudness, but don't push sparse sounds (crickets,
    // thunder) so hard that their peaks distort.
    final gain = min(0.16 / rms, peakLimit / peak);
    for (var i = 0; i < s.length; i++) {
      s[i] = _softClip(s[i] * gain);
    }
  }

  static double _softClip(double x) {
    final a = x.abs();
    if (a <= 0.7) return x;
    final y = 0.7 + 0.28 * _tanh((a - 0.7) / 0.28);
    return x < 0 ? -y : y;
  }

  static double _tanh(double x) {
    final e = exp(2 * x);
    return (e - 1) / (e + 1);
  }

  static double _coef(double cutoffHz) =>
      1 - exp(-2 * pi * cutoffHz / sampleRate);

  static double _white(Random r) => r.nextDouble() * 2 - 1;

  // ── Sounds ──

  static void _rain(Float64List out, Random r, {required bool heavy}) {
    final pink = _Pink();
    final lp = _coef(heavy ? 3200 : 5200);
    final hp = _coef(heavy ? 180 : 350);
    var low = 0.0, dc = 0.0;
    for (var i = 0; i < out.length; i++) {
      final x = pink.next(r);
      low += lp * (x - low);
      dc += hp * (low - dc);
      out[i] = (low - dc) * (heavy ? 1.0 : 0.7);
    }

    // Individual drops: short, bright, decaying noise bursts.
    final dropsPerSecond = heavy ? 70 : 38;
    final drops = out.length * dropsPerSecond ~/ sampleRate;
    for (var d = 0; d < drops; d++) {
      final start = r.nextInt(out.length);
      final len = (sampleRate * (0.004 + r.nextDouble() * 0.012)).round();
      final amp = pow(r.nextDouble(), 2.2) * (heavy ? 0.35 : 0.5);
      var prev = 0.0;
      for (var k = 0; k < len && start + k < out.length; k++) {
        final w = _white(r);
        final bright = w - prev;
        prev = w;
        out[start + k] += bright * amp * exp(-k / (len * 0.25));
      }
    }
  }

  static void _thunder(Float64List out, Random r, int loopLen) {
    // Two strikes at uneven spacing so the loop doesn't feel metronomic.
    final strikes = [loopLen * 0.18, loopLen * 0.63];
    for (final s in strikes) {
      final start = s.round() + r.nextInt(sampleRate * 2);
      final len = sampleRate * (5 + r.nextInt(3));
      var brown = 0.0, low = 0.0, crackLow = 0.0;
      final rumbleLp = _coef(140);
      final crackLp = _coef(1100);
      // A few overlapping rolls give the rumble its uneven body.
      final rolls = List.generate(4, (_) => r.nextDouble() * len * 0.6);
      for (var k = 0; k < len && start + k < out.length; k++) {
        final t = k / sampleRate;
        final w = _white(r);
        brown = (brown + 0.02 * w) / 1.02;
        low += rumbleLp * (brown * 3.5 - low);
        crackLow += crackLp * (w - crackLow);

        var env = (1 - exp(-t / 0.08)) * exp(-t / 2.2);
        for (final roll in rolls) {
          final dt = (k - roll) / sampleRate;
          if (dt > 0) env += 0.5 * exp(-dt / 0.9) * (1 - exp(-dt / 0.15));
        }
        final crack = t < 0.35 ? crackLow * exp(-t / 0.08) * 1.4 : 0.0;
        out[start + k] += low * env * 4.0 + crack;
      }
    }
  }

  static void _waves(Float64List out, Random r, int loopLen) {
    final pink = _Pink();
    var brown = 0.0, low = 0.0;
    final p1 = loopLen / 4; // 8 s swell
    final p2 = loopLen / 5; // 6.4 s secondary swell
    for (var i = 0; i < out.length; i++) {
      final a = 0.5 - 0.5 * cos(2 * pi * i / p1);
      final b = 0.5 - 0.5 * cos(2 * pi * i / p2);
      final swell = pow(0.65 * a + 0.35 * b, 2.2).toDouble();
      final env = 0.12 + 0.88 * swell;
      final w = _white(r);
      brown = (brown + 0.02 * w) / 1.02;
      final x = pink.next(r) * 0.6 + brown * 2.0;
      // The wash brightens as the wave breaks.
      low += _coef(250 + 2400 * swell) * (x - low);
      out[i] = low * env;
    }
  }

  static void _fire(Float64List out, Random r) {
    var brown = 0.0, low = 0.0;
    final lp = _coef(420);
    for (var i = 0; i < out.length; i++) {
      final w = _white(r);
      brown = (brown + 0.02 * w) / 1.02;
      low += lp * (brown * 3.5 - low);
      out[i] = low * 0.55;
    }
    // Crackles come in small clusters, like real embers popping.
    var pos = 0;
    while (pos < out.length) {
      pos += (sampleRate * (0.05 + r.nextDouble() * 0.35)).round();
      final cluster = 1 + r.nextInt(r.nextDouble() < 0.2 ? 6 : 2);
      var c = pos;
      for (var j = 0; j < cluster; j++) {
        c += (sampleRate * r.nextDouble() * 0.03).round();
        final isPop = r.nextDouble() < 0.12;
        final len = (sampleRate * (isPop ? 0.02 : 0.003 + r.nextDouble() * 0.004)).round();
        final amp = (isPop ? 0.6 : 0.9) * (0.2 + pow(r.nextDouble(), 1.5) * 0.8);
        var prev = 0.0;
        for (var k = 0; k < len && c + k < out.length; k++) {
          final w = _white(r);
          final s = isPop ? w : w - prev;
          prev = w;
          out[c + k] += s * amp * exp(-k / (len * 0.3));
        }
      }
    }
  }

  static void _wind(Float64List out, Random r, int loopLen) {
    final pink = _Pink();
    var low = 0.0, band = 0.0;
    final p1 = loopLen / 3; // 12 s gusts
    final p2 = loopLen / 5; // 7.2 s flutter
    for (var i = 0; i < out.length; i++) {
      final g1 = 0.5 - 0.5 * cos(2 * pi * i / p1);
      final g2 = 0.5 - 0.5 * cos(2 * pi * i / p2 + 1.3);
      final gust = 0.6 * g1 + 0.4 * g2;
      final fc = 280 + 650 * gust;
      final f = 2 * sin(pi * fc / sampleRate);
      const q = 0.35;
      final x = pink.next(r);
      low += f * band;
      final high = x - low - q * band;
      band += f * high;
      out[i] = band * (0.25 + 0.75 * gust);
    }
  }

  static void _night(Float64List out, Random r) {
    final pink = _Pink();
    var low = 0.0;
    final lp = _coef(900);
    for (var i = 0; i < out.length; i++) {
      low += lp * (pink.next(r) - low);
      out[i] = low * 0.35;
    }
    // A few crickets, each with its own pitch and rhythm.
    for (var c = 0; c < 3; c++) {
      final freq = 4100.0 + c * 260 + r.nextDouble() * 120;
      final pan = 0.25 + r.nextDouble() * 0.2;
      final pulses = 3 + r.nextInt(2);
      final interval = 0.55 + r.nextDouble() * 0.5;
      var t = r.nextDouble() * interval;
      final total = out.length / sampleRate;
      while (t < total) {
        if (r.nextDouble() > 0.12) {
          for (var p = 0; p < pulses; p++) {
            final start = ((t + p * 0.028) * sampleRate).round();
            final len = (0.016 * sampleRate).round();
            for (var k = 0; k < len && start + k < out.length; k++) {
              final env = sin(pi * k / len);
              out[start + k] += sin(2 * pi * freq * (start + k) / sampleRate) * env * pan;
            }
          }
        }
        t += interval * (0.9 + r.nextDouble() * 0.2);
      }
    }
  }

  static void _brown(Float64List out, Random r) {
    var brown = 0.0, low = 0.0;
    final lp = _coef(900);
    for (var i = 0; i < out.length; i++) {
      final w = _white(r);
      brown = (brown + 0.02 * w) / 1.02;
      low += lp * (brown * 3.5 - low);
      out[i] = low;
    }
  }

  static Uint8List encodeWav(Float64List samples) {
    final dataLen = samples.length * 2;
    final bytes = ByteData(44 + dataLen);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bytes.setInt16(44 + i * 2, v, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

/// Paul Kellet's pink noise filter.
class _Pink {
  double _b0 = 0, _b1 = 0, _b2 = 0, _b3 = 0, _b4 = 0, _b5 = 0, _b6 = 0;

  double next(Random r) {
    final w = r.nextDouble() * 2 - 1;
    _b0 = 0.99886 * _b0 + w * 0.0555179;
    _b1 = 0.99332 * _b1 + w * 0.0750759;
    _b2 = 0.96900 * _b2 + w * 0.1538520;
    _b3 = 0.86650 * _b3 + w * 0.3104856;
    _b4 = 0.55000 * _b4 + w * 0.5329522;
    _b5 = -0.7616 * _b5 - w * 0.0168980;
    final out = _b0 + _b1 + _b2 + _b3 + _b4 + _b5 + _b6 + w * 0.5362;
    _b6 = w * 0.115926;
    return out * 0.11;
  }
}
