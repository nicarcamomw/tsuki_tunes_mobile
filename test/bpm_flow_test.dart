import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/flow_sheet.dart';

import 'helpers/test_scope.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: '',
      artistName: 'Artist',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    );

List<String> _ids(List<Track> l) => l.map((t) => t.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('tempo feel', () {
    test('half and double time fold into one octave', () {
      expect(BpmFlow.feel(70), 140);
      expect(BpmFlow.feel(140), 140);
      expect(BpmFlow.feel(60), 120);
      expect(BpmFlow.feel(175), 87.5);
      expect(BpmFlow.feel(85), 85);
      expect(BpmFlow.feel(169), 169);
    });
  });

  group('arrange', () {
    final tracks = [for (final id in 'abcdef'.split('')) _t(id)];
    final bpms = {'a': 128.0, 'b': 90.0, 'd': 64.0, 'e': 100.0, 'f': 110.0};
    // c has no known tempo. Feels: a 128, b 90, d 128 (64×2), e 100, f 110.

    test('rise climbs gradually and keeps unknown tracks in place', () {
      final r = BpmFlow.arrange(tracks, bpms, FlowMode.rise);
      expect(_ids(r.order), ['b', 'e', 'c', 'f', 'a', 'd']);
      expect(r.known, 5);
      expect(r.total, 6);
      expect(r.fromBpm, 90);
      expect(r.toBpm, 128);
    });

    test('equal tempos keep their original order', () {
      final r = BpmFlow.arrange(tracks, bpms, FlowMode.rise);
      expect(_ids(r.order).indexOf('a'), lessThan(_ids(r.order).indexOf('d')));
    });

    test('calm winds down', () {
      final r = BpmFlow.arrange(tracks, bpms, FlowMode.calm);
      final feels = [
        for (final t in r.order)
          if (bpms[t.id] != null) BpmFlow.feel(bpms[t.id]!),
      ];
      for (var i = 1; i < feels.length; i++) {
        expect(feels[i], lessThanOrEqualTo(feels[i - 1]));
      }
      expect(r.order[2].id, 'c');
    });

    test('wave peaks about two thirds in and comes back down', () {
      final many = [for (var i = 0; i < 12; i++) _t('$i')];
      final tempos = {for (var i = 0; i < 12; i++) '$i': 90.0 + i * 5};
      final r = BpmFlow.arrange(many, tempos, FlowMode.wave);
      final feels = [for (final t in r.order) tempos[t.id]!];
      final peakAt = feels.indexOf(feels.reduce((a, b) => a > b ? a : b));
      expect(peakAt, inInclusiveRange(6, 9));
      expect(feels.last, lessThan(feels[peakAt]));
      expect(r.peakBpm, 145);
      expect(_ids(r.order).toSet(), _ids(many).toSet());
    });

    test('nothing known leaves the queue untouched', () {
      final r = BpmFlow.arrange(tracks, const {}, FlowMode.rise);
      expect(_ids(r.order), _ids(tracks));
      expect(r.coverage, 0);
    });
  });

  group('BpmService', () {
    test('asks Deezer once per track and remembers, unknown included', () async {
      final calls = <String>[];
      Future<TrackAudioInfo?> fetch(String id) async {
        calls.add(id);
        return TrackAudioInfo(bpm: id == 'x' ? 0 : 120);
      }

      final s = BpmService(fetch: fetch, gap: Duration.zero);
      final first = await s.lookup([_t('a'), _t('b'), _t('x')]);
      expect(first, {'a': 120.0, 'b': 120.0});
      expect(calls.length, 3);

      final again = BpmService(fetch: fetch, gap: Duration.zero);
      await again.lookup([_t('a'), _t('b'), _t('x'), _t('c')]);
      expect(calls.length, 4, reason: 'only the new track is fetched after a restart');
    });

    test('the same track asked from two places is fetched once, and says so', () async {
      final calls = <String>[];
      final s = BpmService(
        fetch: (id) async {
          calls.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const TrackAudioInfo(bpm: 128, gain: -9);
        },
        gap: Duration.zero,
      );
      var bumps = 0;
      s.revision.addListener(() => bumps++);
      await Future.wait([s.ensure('a'), s.lookup([_t('a'), _t('b')]), s.ensure('a')]);
      expect(calls..sort(), ['a', 'b']);
      expect(s.cached('a'), 128);
      expect(bumps, 2, reason: 'what shows the tempo hears about each new one');
    });

    test('failed requests are counted and retried next time', () async {
      var online = false;
      final s = BpmService(
        fetch: (_) async => online ? const TrackAudioInfo(bpm: 100) : null,
        gap: Duration.zero,
      );
      expect(await s.lookup([_t('a')]), isEmpty);
      expect(s.lastFailures, 1);
      online = true;
      expect(await s.lookup([_t('a')]), {'a': 100.0});
      expect(s.lastFailures, 0);
    });

    test('requests are paced under the Deezer rate limit', () async {
      final s = BpmService(
          fetch: (_) async => const TrackAudioInfo(bpm: 100),
          gap: const Duration(milliseconds: 20));
      final sw = Stopwatch()..start();
      await s.lookup([for (var i = 0; i < 10; i++) _t('$i')], concurrency: 4);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });
  });

  group('loudness', () {
    test('only louder-than-target tracks are turned down, within a limit', () {
      expect(Loudness.factorFor(null), 1.0);
      expect(Loudness.factorFor(-15), 1.0, reason: 'quiet tracks are never boosted');
      expect(Loudness.factorFor(Loudness.targetGain), 1.0);
      // 6 dB louder than the target: half the amplitude.
      expect(Loudness.factorFor(Loudness.targetGain + 6), closeTo(0.501, 0.001));
      // Capped at maxCutDb.
      expect(Loudness.factorFor(10), closeTo(0.355, 0.001));
    });

    test('a louder track always ends up at or below a quieter one', () {
      var prev = 1.0;
      for (var g = -20.0; g <= 0; g += 0.5) {
        final f = Loudness.factorFor(g);
        expect(f, lessThanOrEqualTo(prev));
        prev = f;
      }
    });

    test('gain is fetched once and remembered with the tempo', () async {
      var calls = 0;
      final s = BpmService(
        fetch: (_) async {
          calls++;
          return const TrackAudioInfo(bpm: 0, gain: -8.5);
        },
        gap: Duration.zero,
      );
      expect(await s.gainFor('a'), -8.5);
      expect(await s.gainFor('a'), -8.5);
      expect(calls, 1);
      expect(await s.lookup([_t('a')]), isEmpty, reason: 'bpm unknown, not refetched');
      expect(calls, 1);
    });
  });

  test('queue keeps played tracks and only accepts a reordering', () {
    final q = PlaybackQueue();
    final all = [for (final id in 'abcde'.split('')) _t(id)];
    q.select(all[1], newQueue: all);
    q.replaceUpcoming([all[4], all[2], all[3]]);
    expect(_ids(q.tracks), ['a', 'b', 'e', 'c', 'd']);
    expect(q.current?.id, 'b');

    q.replaceUpcoming([all[2]]);
    expect(_ids(q.tracks), ['a', 'b', 'e', 'c', 'd'], reason: 'not a permutation: ignored');
  });

  testWidgets('flow sheet reports coverage and reorders the queue', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final audio = AudioProvider();
    final queue = [for (final id in 'pabcde'.split('')) _t(id)];
    const tempos = {'a': 128.0, 'b': 90.0, 'c': 0.0, 'd': 110.0, 'e': 100.0};
    final service = BpmService(
        fetch: (id) async => TrackAudioInfo(bpm: tempos[id] ?? 0), gap: Duration.zero);

    await tester.runAsync(() async {
      try {
        await audio.playTrack(queue.first, newQueue: queue);
      } catch (_) {}
    });
    await tester.pumpWidget(TestScope(
        overrides: [
          audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
          bpmProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: Scaffold(body: FlowSheet()))));
    // The fake lookup resolves in microtasks; a few frames are enough.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.text('BPM conocido en 4 de 5 canciones'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);

    await tester.tap(find.text('Subir energía'));
    await tester.pumpAndSettle();
    expect(_ids(audio.upcomingTracks), ['b', 'e', 'c', 'd', 'a']);
  });
}
