import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/providers/locale_provider.dart';
import 'package:tsuki_tunes_mobile/providers/run_provider.dart';
import 'package:tsuki_tunes_mobile/providers/shake_skip_provider.dart';
import 'package:tsuki_tunes_mobile/screens/run_mode_screen.dart';
import 'package:tsuki_tunes_mobile/services/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/services/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/services/cadence_detector.dart';
import 'package:tsuki_tunes_mobile/services/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/services/motion_sensor.dart';
import 'package:tsuki_tunes_mobile/services/pace_matcher.dart';
import 'package:tsuki_tunes_mobile/services/run_catalog.dart';
import 'package:tsuki_tunes_mobile/services/shake_detector.dart';

const _g = 9.81;

Track _t(String id, {String artist = 'a'}) => Track(
      id: id,
      title: 'Song $id',
      artistId: artist,
      artistName: 'Artist $artist',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: 'https://example.com/$id.mp3',
      durationSeconds: 30,
    );

/// Steps at [spm] as accelerometer samples at 50 Hz from [from] seconds.
List<MotionSample> _steps(double spm, double seconds, {double from = 0, double impact = 3}) {
  final out = <MotionSample>[];
  final period = 60 / spm;
  for (var t = from; t < from + seconds; t += 0.02) {
    final d = (t - from) % period;
    final p = period / 0.5;
    final v = impact * exp(-pow(d / (0.04 * p), 2)) +
        0.4 * impact * exp(-pow((d - 0.15 * p) / (0.07 * p), 2)) -
        0.35 * impact * exp(-pow((d - 0.3 * p) / (0.1 * p), 2));
    out.add(MotionSample(0.3 * (_g + v), 0.85 * (_g + v), 0.43 * (_g + v),
        Duration(microseconds: (t * 1e6).round())));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async {
        if (call.method == 'init') {
          final id = call.arguments['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (_) async => {},
          );
          for (final kind in ['events', 'data']) {
            messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.$kind.$id'),
              (_) async => null,
            );
          }
        }
        return {};
      },
    );
  });

  group('shake', () {
    bool feed(ShakeDetector d, double Function(double t) ax, double seconds, {double from = 0}) {
      var fired = false;
      for (var t = from; t < from + seconds; t += 0.02) {
        if (d.add(ax(t), _g, 0, Duration(microseconds: (t * 1e6).round()))) fired = true;
      }
      return fired;
    }

    test('a firm half-second shake fires once', () {
      final d = ShakeDetector();
      var count = 0;
      for (var t = 0.0; t < 0.9; t += 0.02) {
        if (d.add(30 * sin(2 * pi * 6 * t).sign * 1.0 + 5 * sin(2 * pi * 6 * t), _g, 0,
            Duration(microseconds: (t * 1e6).round()))) {
          count++;
        }
      }
      expect(count, 1);
    });

    test('walking and running never count as a shake', () {
      final d = ShakeDetector();
      for (final s in [..._steps(120, 20), ..._steps(170, 20, from: 20, impact: 30)]) {
        expect(d.add(s.x, s.y, s.z, s.t), isFalse);
      }
    });

    test('a single knock is not a shake', () {
      final d = ShakeDetector();
      expect(feed(d, (t) => (t - 1).abs() < 0.08 ? 40 : 0, 2), isFalse);
    });

    test('shaking on and on skips only once per cooldown', () {
      final d = ShakeDetector();
      var count = 0;
      for (var t = 0.0; t < 2.5; t += 0.02) {
        if (d.add(35 * sin(2 * pi * 5 * t).sign, _g, 0, Duration(microseconds: (t * 1e6).round()))) {
          count++;
        }
      }
      expect(count, 2, reason: 'first at ~0.5 s, next after the 1.5 s cooldown');
    });
  });

  group('pace matching', () {
    test('a song matches walking at its tempo, running at half or double', () {
      final m = PaceMatcher.match(122, 120);
      expect(m.stepsPerBeat, 1);
      expect(m.exactRate, closeTo(120 / 122, 1e-9));

      final half = PaceMatcher.match(86, 172);
      expect(half.stepsPerBeat, 2);
      expect(half.deviation, closeTo(0, 1e-9));

      final dnb = PaceMatcher.match(174, 88);
      expect(dnb.stepsPerBeat, 0.5);
    });

    test('half time is not used for walking, nor double time for running', () {
      expect(PaceMatcher.match(60, 120).stepsPerBeat, 1);
      expect(PaceMatcher.match(340, 170).stepsPerBeat, 1);
    });

    test('playback speed locks onto the steps within ±8%', () {
      expect(PaceMatcher.playbackRate(120, 126), closeTo(1.05, 1e-9));
      expect(PaceMatcher.playbackRate(120, 135), 1.08, reason: 'closest it can get');
      expect(PaceMatcher.playbackRate(120, 180), 1.0, reason: 'too far: left alone');
      expect(PaceMatcher.playbackRate(85, 170), closeTo(1.0, 1e-9));
    });

    test('picks the closest tempo, skips repeats and avoids the same artist twice', () {
      final tracks = [_t('x', artist: 'A'), _t('y', artist: 'B'), _t('z', artist: 'C'), _t('far')];
      final bpms = {'x': 121.0, 'y': 124.0, 'z': 118.0, 'far': 150.0};
      final rng = Random(1);

      expect(
          PaceMatcher.pick(tracks, bpms, 120, avoid: {'x', 'y', 'z'}, random: rng), isNull,
          reason: '150 BPM is not a match for 120 steps/min');

      var sameArtist = 0;
      for (var i = 0; i < 200; i++) {
        final p = PaceMatcher.pick(tracks, bpms, 120, lastArtistId: 'A', random: rng)!;
        expect(p.id, isNot('far'));
        if (p.artistId == 'A') sameArtist++;
      }
      expect(sameArtist, lessThan(20));
    });
  });

  group('catalog', () {
    test('searches by tempo band, seeded with favourite artists, once per band', () async {
      final queries = <String>[];
      final catalog = RunCatalog(
        bpm: BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 0), gap: Duration.zero),
        search: (q) async {
          queries.add(q);
          return [_t('s${queries.length}')];
        },
      );
      await catalog.warmUp(favorites: const [], recent: const [], favoriteArtistNames: ['Ado']);
      await catalog.explore(120);
      expect(queries, contains('artist:"Ado" bpm_min:"112" bpm_max:"128"'));
      expect(queries, contains('bpm_min:"112" bpm_max:"128"'));
      // Walking that slowly also takes double-time songs.
      expect(queries.any((q) => q.contains('bpm_min:"225"')), isTrue);

      final before = queries.length;
      await catalog.explore(121);
      expect(queries.length, before, reason: 'same band, cached');
    });

    test('verifies the exact tempo of search results before choosing one', () async {
      const tempos = {'off': 150.0, 'on': 119.0};
      final fetched = <String>[];
      final catalog = RunCatalog(
        bpm: BpmService(
          fetch: (id) async {
            fetched.add(id);
            return TrackAudioInfo(bpm: tempos[id] ?? 0);
          },
          gap: Duration.zero,
        ),
        search: (_) async => [_t('off'), _t('on')],
      );
      await catalog.warmUp(favorites: const [], recent: const [], favoriteArtistNames: const []);
      await catalog.explore(120);
      final pick = await catalog.next(120, random: Random(3));
      expect(pick?.id, 'on');
      expect(catalog.bpms['on'], 119);
    });

    test("the listener's own songs with a known tempo come first", () async {
      final own = [_t('fav', artist: 'F'), _t('slow', artist: 'S')];
      final catalog = RunCatalog(
        bpm: BpmService(
          fetch: (id) async => TrackAudioInfo(bpm: id == 'fav' ? 122 : 70),
          gap: Duration.zero,
        ),
        search: (_) async => throw StateError('should not search'),
      );
      await catalog.warmUp(favorites: own, recent: const [], favoriteArtistNames: const []);
      expect((await catalog.next(120))?.id, 'fav');
    });
  });

  group('run mode', () {
    late StreamController<MotionSample> sensor;
    late AudioPlayerService service;
    late AudioProvider audio;
    late RunProvider run;
    late Map<String, double> tempos;

    Future<void> walk(double spm, double seconds, {double from = 0}) async {
      for (final s in _steps(spm, seconds, from: from, impact: spm >= 140 ? 30 : 3)) {
        sensor.add(s);
      }
      await Future<void>.delayed(Duration.zero);
      run.tickForTesting();
      // Let the queue fill (searches, tempo lookups, playTrack).
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    setUp(() async {
      sensor = StreamController<MotionSample>.broadcast();
      service = AudioPlayerService();
      audio = AudioProvider(service: service);
      tempos = {
        for (var i = 0; i < 6; i++) 'w$i': 118.0 + i, // walking songs
        for (var i = 0; i < 6; i++) 'r$i': 84.0 + i, // half-time running songs
        for (var i = 0; i < 6; i++) 'f$i': 166.0 + i, // running songs
      };
      run = RunProvider(
        sensor: () => sensor.stream,
        random: Random(5),
        catalog: () => RunCatalog(
          bpm: BpmService(
              fetch: (id) async => TrackAudioInfo(bpm: tempos[id] ?? 0), gap: Duration.zero),
          search: (q) async {
            final lo = int.parse(RegExp(r'bpm_min:"(\d+)"').firstMatch(q)!.group(1)!);
            final hi = int.parse(RegExp(r'bpm_max:"(\d+)"').firstMatch(q)!.group(1)!);
            return [
              for (final e in tempos.entries)
                if (e.value >= lo && e.value <= hi) _t(e.key, artist: e.key),
            ];
          },
        ),
      );
      run.attach(audio, LibraryProvider());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() async {
      await run.stop();
      await sensor.close();
    });

    test('starts music at the walking pace and keeps songs lined up', () async {
      await run.start();
      expect(run.phase, RunPhase.waiting);

      await walk(120, 8);
      expect(run.reading.spm, closeTo(120, 3));
      expect(run.reading.state, MotionState.walking);
      expect(run.target, isNotNull);

      expect(audio.currentTrack?.id, startsWith('w'));
      expect(audio.upcomingTracks.length, RunProvider.lookahead);
      expect(audio.upcomingTracks.every((t) => t.id.startsWith('w')), isTrue);
      expect(run.phase, RunPhase.playing);
      // Synced: the song is nudged to the steps.
      final bpm = tempos[audio.currentTrack!.id]!;
      expect(service.speedFor!(audio.currentTrack!), closeTo(PaceMatcher.playbackRate(bpm, run.target!), 1e-9));
    });

    test('speeding up to a run swaps what is lined up for running songs', () async {
      await run.start();
      await walk(120, 8);
      final playing = audio.currentTrack!.id;

      await walk(170, 9, from: 8);
      expect(run.reading.state, MotionState.running);
      expect(audio.currentTrack!.id, playing, reason: 'the current song finishes');
      expect(audio.upcomingTracks.length, RunProvider.lookahead);
      expect(audio.upcomingTracks.every((t) => !t.id.startsWith('w')), isTrue);
    });

    test('lock holds the pace; stop puts the speed back to normal', () async {
      await run.start();
      await walk(120, 8);
      run.lock();
      final held = run.target;
      await walk(170, 9, from: 8);
      expect(run.target, held);
      expect(audio.upcomingTracks.every((t) => t.id.startsWith('w')), isTrue);

      run.nudgeLock(4);
      expect(run.target, held! + 4);

      await run.stop();
      expect(service.speedFor, isNull);
      expect(run.active, isFalse);
    });

    test('the mode can be switched off, which ends a session', () async {
      expect(run.enabled, isTrue);
      await run.start();
      await walk(120, 8);
      await run.setEnabled(false);
      expect(run.active, isFalse);
      expect(service.speedFor, isNull);

      await run.start();
      expect(run.active, isFalse, reason: 'off: does not start');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('run_mode_enabled'), isFalse);

      await run.setEnabled(true);
      await run.start();
      expect(run.active, isTrue);
    });

    test('turning sync off plays songs at their own speed', () async {
      await run.start();
      await walk(126, 8);
      await run.setSyncTempo(false);
      expect(service.speedFor!(audio.currentTrack!), 1.0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('run_sync_tempo'), isFalse);
    });

    test('a missing sensor falls back to a pace set by hand', () async {
      final failing = RunProvider(
        sensor: () => Stream<MotionSample>.error(PlatformException(code: 'NO_SENSOR')),
        catalog: () => RunCatalog(
          bpm: BpmService(fetch: (id) async => TrackAudioInfo(bpm: tempos[id] ?? 0), gap: Duration.zero),
          search: (_) async => [_t('w2', artist: 'x')],
        ),
      )..attach(audio, LibraryProvider());
      await failing.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(failing.sensorAvailable, isFalse);
      expect(failing.isLocked, isTrue);
      expect(failing.target, 120);
      expect(audio.currentTrack?.id, 'w2');
      await failing.stop();
    });

    test('shake to skip is off by default and pauses during run mode', () async {
      final shakes = StreamController<MotionSample>.broadcast();
      var listens = 0;
      final shake = ShakeSkipProvider(sensor: () {
        listens++;
        return shakes.stream;
      })
        ..attach(audio, run);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(shake.enabled, isFalse);
      expect(shake.listening, isFalse);

      // Loading never finishes against the mocked player; the queue is set at once.
      unawaited(audio.playTrack(_t('a'), newQueue: [_t('a'), _t('b')]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await shake.setEnabled(true);
      expect(shake.listening, isTrue);

      for (var t = 0.0; t < 0.7; t += 0.02) {
        shakes.add(MotionSample(35 * sin(2 * pi * 5 * t).sign, _g, 0,
            Duration(microseconds: (t * 1e6).round())));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.currentTrack?.id, 'b');

      await run.start();
      expect(shake.listening, isFalse, reason: 'running shakes the phone all the time');
      await run.stop();
      expect(shake.listening, isTrue);
      expect(listens, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('shake_to_skip'), isTrue);
      shake.dispose();
      await shakes.close();
    });
  });

  testWidgets('run screen fits a small phone in every state', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 690 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final sensor = StreamController<MotionSample>.broadcast();
    // The player and its tickers run on the real clock, set up before
    // anything is drawn.
    final audio = (await tester.runAsync(() async {
      final a = AudioProvider();
      unawaited(a.playTrack(_t('w1'), newQueue: [_t('w1')]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return a;
    }))!;
    final run = RunProvider(
      sensor: () => sensor.stream,
      catalog: () => RunCatalog(
        bpm: BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 121), gap: Duration.zero),
        search: (_) async => const [],
      ),
    )..attach(audio, LibraryProvider());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: audio),
        ChangeNotifierProvider.value(value: run),
      ],
      child: const MaterialApp(home: RunModeScreen()),
    ));
    await tester.pump();
    expect(find.text('INICIAR'), findsOneWidget);
    expect(find.text('- - -'), findsOneWidget);

    await tester.tap(find.text('INICIAR'));
    await tester.pump();
    for (final s in _steps(124, 8)) {
      sensor.add(s);
    }
    await tester.pump();
    run.tickForTesting();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('TERMINAR'), findsOneWidget);
    expect(find.text('CAMINANDO'), findsOneWidget);
    expect(find.text('Song w1'), findsOneWidget);
    expect(find.textContaining('121 BPM'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fijar ritmo'));
    await tester.pump();
    expect(find.text('Seguir mis pasos'), findsOneWidget);
    expect(find.byTooltip('+2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('TERMINAR'));
    await tester.pump();
    expect(find.text('INICIAR'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    unawaited(sensor.close());
  });
}
