import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/logic/equalizer_presets.dart';

void main() {
  test('off is flat everywhere', () {
    for (final hz in [20.0, 60.0, 1000.0, 16000.0, 20000.0]) {
      expect(EqCurves.gainAt(EqPreset.off, hz), 0);
    }
  });

  test('each preset leans where its name says', () {
    expect(EqCurves.gainAt(EqPreset.bass, 60), greaterThan(EqCurves.gainAt(EqPreset.bass, 4000)));
    expect(EqCurves.gainAt(EqPreset.vocal, 2500), greaterThan(EqCurves.gainAt(EqPreset.vocal, 60)));
    expect(EqCurves.gainAt(EqPreset.night, 16000), lessThan(0));
    // Rock is a smile: both ends above the middle.
    expect(EqCurves.gainAt(EqPreset.rock, 60), greaterThan(EqCurves.gainAt(EqPreset.rock, 1000)));
    expect(EqCurves.gainAt(EqPreset.rock, 14000), greaterThan(EqCurves.gainAt(EqPreset.rock, 1000)));
  });

  test('between two points the gain follows a log scale, and stays in the phone\'s range', () {
    // Halfway between 60 and 150 Hz on a log scale is about 95 Hz.
    final mid = EqCurves.gainAt(EqPreset.bass, 94.87);
    expect(mid, closeTo(5, 0.05));
    expect(EqCurves.gainAt(EqPreset.bass, 60, max: 3), 3);
    for (final p in EqPreset.values) {
      for (var hz = 20.0; hz <= 20000; hz *= 1.5) {
        expect(EqCurves.gainAt(p, hz).abs(), lessThanOrEqualTo(6), reason: '$p at $hz Hz');
      }
    }
  });

  test('a saved name comes back as its preset; anything else is off', () {
    expect(EqCurves.fromName('rock'), EqPreset.rock);
    expect(EqCurves.fromName(null), EqPreset.off);
    expect(EqCurves.fromName('loudness_war'), EqPreset.off);
  });
}
