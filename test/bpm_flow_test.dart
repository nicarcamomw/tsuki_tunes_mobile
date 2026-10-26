import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/locale_provider.dart';
import 'package:tsuki_tunes_mobile/services/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/services/playback_queue.dart';
import 'package:tsuki_tunes_mobile/widgets/flow_sheet.dart';

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
      Future<double?> fetch(String id) async {
        calls.add(id);
        return id == 'x' ? 0 : 120;
      }

      final s = BpmService(fetch: fetch, gap: Duration.zero);
      final first = await s.lookup([_t('a'), _t('b'), _t('x')]);
      expect(first, {'a': 120.0, 'b': 120.0});
      expect(calls.length, 3);

      final again = BpmService(fetch: fetch, gap: Duration.zero);
      await again.lookup([_t('a'), _t('b'), _t('x'), _t('c')]);
      expect(calls.length, 4, reason: 'only the new track is fetched after a restart');
    });

    test('failed requests are counted and retried next time', () async {
      var online = false;
      final s = BpmService(
        fetch: (_) async => online ? 100 : null,
        gap: Duration.zero,
      );
      expect(await s.lookup([_t('a')]), isEmpty);
      expect(s.lastFailures, 1);
      online = true;
      expect(await s.lookup([_t('a')]), {'a': 100.0});
      expect(s.lastFailures, 0);
    });

    test('requests are paced under the Deezer rate limit', () async {
      final s = BpmService(fetch: (_) async => 100, gap: const Duration(milliseconds: 20));
      final sw = Stopwatch()..start();
      await s.lookup([for (var i = 0; i < 10; i++) _t('$i')], concurrency: 4);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
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
    final service = BpmService(fetch: (id) async => tempos[id], gap: Duration.zero);

    await tester.runAsync(() async {
      try {
        await audio.playTrack(queue.first, newQueue: queue);
      } catch (_) {}
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: audio),
      ],
      child: MaterialApp(home: Scaffold(body: FlowSheet(service: service))),
    ));
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
