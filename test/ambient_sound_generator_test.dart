import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/logic/ambient_sound_generator.dart';

void main() {
  group('AmbientSoundGenerator', () {
    for (final sound in AmbientSound.values) {
      test('${sound.name} renders a full, audible, in-range loop', () {
        final s = AmbientSoundGenerator.generateSamples(sound);
        expect(s.length,
            AmbientSoundGenerator.loopSeconds(sound) * AmbientSoundGenerator.sampleRate);

        var sum = 0.0;
        for (final v in s) {
          expect(v.isFinite, isTrue);
          expect(v.abs(), lessThanOrEqualTo(1.0));
          sum += v * v;
        }
        final rms = sqrt(sum / s.length);
        expect(rms, greaterThan(0.05));
      });

      test('${sound.name} loops without an audible click', () {
        final s = AmbientSoundGenerator.generateSamples(sound);
        // The jump from the last sample back to the first should be no larger
        // than the typical step between neighbouring samples.
        var maxStep = 0.0;
        for (var i = 1; i < s.length; i++) {
          maxStep = max(maxStep, (s[i] - s[i - 1]).abs());
        }
        expect((s.first - s.last).abs(), lessThanOrEqualTo(maxStep));
      });
    }

    test('generation is deterministic so the disk cache stays valid', () {
      final a = AmbientSoundGenerator.generateSamples(AmbientSound.rain);
      final b = AmbientSoundGenerator.generateSamples(AmbientSound.rain);
      expect(a, b);
    });

    test('WAV header describes 16-bit mono PCM', () {
      final wav = AmbientSoundGenerator.encodeWav(Float64List.fromList([0, 0.5, -0.5]));
      final d = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(d.getUint16(22, Endian.little), 1);
      expect(d.getUint32(24, Endian.little), AmbientSoundGenerator.sampleRate);
      expect(d.getUint16(34, Endian.little), 16);
      expect(d.getUint32(40, Endian.little), 6);
      expect(wav.length, 44 + 6);
      expect(d.getInt16(46, Endian.little), 16384);
    });
  });
}
