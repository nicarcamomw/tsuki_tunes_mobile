import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/services/beat_clock.dart';
import 'package:tsuki_tunes_mobile/services/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/services/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/widgets/rinnegan_visualizer.dart';
import 'helpers/test_scope.dart';

Duration _s(double s) => Duration(microseconds: (s * 1e6).round());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('pulse', () {
    test('rises softly, peaks early and decays', () {
      expect(BeatPulse.envelope(0), 0);
      expect(BeatPulse.envelope(0.07), closeTo(1, 1e-9));
      expect(BeatPulse.envelope(0.035), closeTo(0.5, 1e-9));
      var prev = 1.0;
      for (var p = 0.08; p < 1; p += 0.05) {
        final e = BeatPulse.envelope(p);
        expect(e, lessThan(prev));
        prev = e;
      }
      expect(BeatPulse.envelope(0.99), lessThan(0.02));
      expect(BeatPulse.envelope(1.5), BeatPulse.envelope(0.5), reason: 'periodic');
    });

    test('fast songs pulse in half time, slow ones on every beat', () {
      expect(BeatPulse.pulseBeats(60), 1);
      expect(BeatPulse.pulseBeats(128), 1);
      expect(BeatPulse.pulseBeats(140), 1);
      expect(BeatPulse.pulseBeats(174), 2);
      expect(BeatPulse.pulseBeats(300), 4);
    });

    test('a grid counts beats from its offset and marks the bars', () {
      const g = BeatGrid(120, offset: 0.2, barShift: 1);
      expect(g.beatsAt(0.2), 0);
      expect(g.beatsAt(1.2), 2);
      expect(g.isDownbeat(1), isTrue);
      expect(g.isDownbeat(5), isTrue);
      expect(g.isDownbeat(2), isFalse);
      expect(BeatGrid.fromJson(g.toJson())!.offset, 0.2);
      expect(BeatGrid.fromJson({'b': 0, 'o': 1}), isNull);
    });
  });

  group('playback clock', () {
    test('runs smoothly between position reports, at the playback speed', () {
      final c = PlaybackClock();
      expect(c.advance(_s(10), _s(0), playing: true), 10);
      // No new report: the clock keeps going on its own.
      expect(c.advance(_s(10), _s(0.1), playing: true, rate: 1.05), closeTo(10.105, 1e-9));
      expect(c.advance(_s(10), _s(0.2), playing: true, rate: 1.05), closeTo(10.21, 1e-9));
    });

    test('a slightly late report is eased in, a seek jumps', () {
      final c = PlaybackClock();
      c.advance(_s(10), _s(0), playing: true);
      final t = c.advance(_s(10.3), _s(0.2), playing: true);
      // Predicted 10.2, reported 10.3: moves only part of the way.
      expect(t, greaterThan(10.2));
      expect(t, lessThan(10.25));
      expect(c.advance(_s(42), _s(0.3), playing: true), 42);
    });

    test('holds still while paused', () {
      final c = PlaybackClock();
      c.advance(_s(5), _s(0), playing: false);
      expect(c.advance(_s(5), _s(3), playing: false), 5);
    });
  });

  group('tap sync', () {
    double phaseError(BeatGrid g, double beatAt) {
      final p = g.beatsAt(beatAt);
      final d = (p - p.round()).abs();
      return d * g.period;
    }

    test('three taps on the beat line the grid up with the song', () {
      final s = TapSync();
      // Song at 120 BPM whose beats fall at 0.31 + k·0.5; human jitter ±15 ms.
      final taps = [10.31 + 0.012, 10.81 - 0.009, 11.31 + 0.004];
      expect(s.tap(taps[0], 0, bpm: 120), isNull);
      expect(s.tap(taps[1], 0.5, bpm: 120), isNull);
      final r = s.tap(taps[2], 1.0, bpm: 120)!;
      expect(r.tappedTempo, isFalse);
      expect(r.grid.bpm, 120, reason: "Deezer's tempo is kept, it is exact over the whole song");
      expect(phaseError(r.grid, 0.31), lessThan(0.012));
      expect(phaseError(r.grid, 100.31), lessThan(0.012), reason: 'stays aligned later on');
      expect(r.grid.isDownbeat(r.grid.beatsAt(10.31).round()), isTrue,
          reason: 'the first tap starts a bar');
    });

    test('tapping every other beat works too', () {
      final s = TapSync();
      for (final t in [3.0, 4.0, 5.0]) {
        s.tap(t + 0.1, t, bpm: 120);
      }
      final r = s.tap(6.1, 6, bpm: 120)!;
      expect(phaseError(r.grid, 0.1), lessThan(0.005));
    });

    test('without a known tempo, four taps set it', () {
      final s = TapSync();
      const period = 60 / 97;
      TapResult? r;
      for (var i = 0; i < 4; i++) {
        r = s.tap(2 + i * period, i * period);
        if (i < 3) expect(r, isNull);
      }
      expect(r!.tappedTempo, isTrue);
      expect(r.grid.bpm, closeTo(97, 0.5));
    });

    test('taps that disagree with Deezer win after four', () {
      final s = TapSync();
      const period = 0.6; // 100 BPM, Deezer says 128
      expect(s.tap(1, 1, bpm: 128), isNull);
      expect(s.tap(1.6, 1.6, bpm: 128), isNull);
      expect(s.tap(2.2, 2.2, bpm: 128), isNull);
      final r = s.tap(1 + 3 * period, 2.8, bpm: 128)!;
      expect(r.tappedTempo, isTrue);
      expect(r.grid.bpm, closeTo(100, 0.5));
    });

    test('a pause of two seconds starts the taps over', () {
      final s = TapSync();
      s.tap(1, 1, bpm: 120);
      s.tap(1.5, 1.5, bpm: 120);
      expect(s.tap(5, 5, bpm: 120), isNull);
      expect(s.count, 1);
    });

    test('random taps are ignored', () {
      final s = TapSync();
      final rng = Random(2);
      var t = 0.0;
      for (var i = 0; i < 6; i++) {
        t += 0.2 + rng.nextDouble() * 0.9;
        final r = s.tap(t, t);
        if (r != null) {
          // Only acceptable if the taps happened to be even.
          fail('locked onto random taps');
        }
      }
    });
  });

  test('tapped grids are remembered per song and source, with a cap', () async {
    final store = BeatSyncStore();
    final key = BeatSyncStore.keyFor('42', fullSong: true);
    expect(key, isNot(BeatSyncStore.keyFor('42', fullSong: false)));
    await store.put(key, const BeatGrid(101, offset: 0.3));

    final again = BeatSyncStore();
    await again.load();
    expect(again.get(key)?.bpm, 101);
    await again.remove(key);
    expect(again.get(key), isNull);

    for (var i = 0; i < BeatSyncStore.maxEntries + 5; i++) {
      await again.put('t$i', const BeatGrid(100));
    }
    expect(again.get('t0'), isNull, reason: 'oldest dropped');
    expect(again.get('t${BeatSyncStore.maxEntries + 4}'), isNotNull);
  });

  testWidgets('the eye beats with the song, shows the hint once and resets on long press',
      (tester) async {
    var position = Duration.zero;
    final tempo = BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 120), gap: Duration.zero);

    Widget eye(bool playing) => TestScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: RinneganVisualizer(
                  isPlaying: playing,
                  size: 260,
                  trackId: 'song',
                  position: () => position,
                  speed: () => 1.0,
                  tempoService: tempo,
                ),
              ),
            ),
          ));

    await tester.pumpWidget(eye(true));
    for (var i = 0; i < 30; i++) {
      position += const Duration(milliseconds: 50);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('TOCA AL RITMO PARA SINCRONIZAR'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('beat_sync_hint_shown'), isTrue);

    await tester.longPress(find.byType(RinneganVisualizer));
    await tester.pump();
    expect(find.text('AUTO · 120 BPM'), findsOneWidget);

    // Pausing lets the animation settle and stop.
    await tester.pumpWidget(eye(false));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
