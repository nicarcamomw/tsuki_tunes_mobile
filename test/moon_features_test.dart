import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/app_providers.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/providers/moon_provider.dart';
import 'package:tsuki_tunes_mobile/providers/playlist_provider.dart';
import 'package:tsuki_tunes_mobile/services/play_history.dart';
import 'package:tsuki_tunes_mobile/widgets/moon_atmosphere.dart';
import 'package:tsuki_tunes_mobile/widgets/moon_button.dart';
import 'package:tsuki_tunes_mobile/widgets/moon_sheet.dart';

import 'helpers/test_scope.dart';

Track _t(String id, {int duration = 200}) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: '',
      albumTitle: '',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: duration,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PlayHistory', () {
    test('ranks by play count, then by most recent play, within the window', () {
      final now = DateTime.utc(2026, 10, 26);
      final entries = [
        PlayEntry('a', now.subtract(const Duration(days: 1))),
        PlayEntry('b', now.subtract(const Duration(days: 2))),
        PlayEntry('b', now.subtract(const Duration(days: 3))),
        PlayEntry('c', now.subtract(const Duration(hours: 1))),
        PlayEntry('old', now.subtract(const Duration(days: 40))),
        PlayEntry('old', now.subtract(const Duration(days: 41))),
        PlayEntry('old', now.subtract(const Duration(days: 42))),
      ];
      final tracks = {for (final id in ['a', 'b', 'c', 'old']) id: _t(id)};
      final ranked = PlayHistory.rank(
        entries: entries,
        tracks: tracks,
        from: now.subtract(const Duration(days: 30)),
        to: now,
      );
      expect(ranked.map((t) => t.id), ['b', 'c', 'a']);
    });

    test('persists plays across restarts', () async {
      final h = PlayHistory();
      await h.record(_t('x'), at: DateTime.utc(2026, 10, 20));
      await h.record(_t('x'), at: DateTime.utc(2026, 10, 21));

      final reloaded = PlayHistory();
      await reloaded.load();
      expect(reloaded.entries.length, 2);
      expect(reloaded.tracks['x']?.title, 'Song x');
    });
  });

  group('countdown text', () {
    const es = AppStrings(AppLanguage.es);

    test('full moon window, hours and days', () {
      expect(MoonSheet.countdown(es, MoonCalculator.snapshot(DateTime.utc(2026, 10, 26, 3))),
          'Luna llena esta noche');
      expect(MoonSheet.countdown(es, MoonCalculator.snapshot(DateTime.utc(2026, 11, 21, 14))),
          'Faltan 3 días para luna llena');
      expect(MoonSheet.countdown(es, MoonCalculator.snapshot(DateTime.utc(2026, 11, 22, 23))),
          contains('días'));
    });
  });

  group('MoonProvider', () {
    test('eclipse preview turns blood mode on and then off', () async {
      var now = DateTime.utc(2026, 11, 12);
      final moon = MoonProvider(clock: () => now, southernHemisphere: true);
      expect(moon.eclipseActive, isFalse);
      moon.previewEclipse();
      expect(moon.eclipseActive, isTrue);
      now = now.add(MoonProvider.eclipsePreviewLength + const Duration(seconds: 1));
      expect(moon.eclipseActive, isFalse);
      moon.dispose();
    });

    test('a real eclipse is detected from the clock alone', () {
      final moon = MoonProvider(clock: () => DateTime.utc(2028, 12, 31, 16, 50));
      expect(moon.eclipseNow?.kind, LunarEclipseKind.total);
      expect(moon.eclipseActive, isTrue);
      moon.dispose();
    });

    test('atmosphere preference is saved', () async {
      final moon = MoonProvider(clock: () => DateTime.utc(2026, 11, 12));
      await moon.setAtmosphereEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('moon_atmosphere_enabled'), isFalse);
      moon.dispose();
    });
  });

  testWidgets('eclipse mode keeps the app state underneath', (tester) async {
    final moon = MoonProvider(clock: DateTime.now);
    await tester.pumpWidget(TestScope(
      overrides: [moonProvider.overrideWith((ref) => moon, disposeNotifier: false)],
      child: const MaterialApp(home: MoonAtmosphere(child: _Counter())),
    ));
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    final bloodLight = find.byWidgetPredicate(
        (w) => w is MoonLightLayer && w.painter is BloodMoonLightPainter);

    moon.previewEclipse();
    await tester.pump();
    expect(bloodLight, findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.pump(MoonProvider.eclipsePreviewLength + const Duration(seconds: 1));
    await tester.pump();
    expect(bloodLight, findsNothing);
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    moon.dispose();
  });

  testWidgets('tapping the moon opens tonight\'s moon with the unlocked mix',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final at = DateTime.utc(2026, 10, 26, 3);
    final history = PlayHistory();
    await history.record(_t('a'), at: at.subtract(const Duration(days: 2)));
    await history.record(_t('a'), at: at.subtract(const Duration(days: 1)));
    await history.record(_t('b'), at: at.subtract(const Duration(days: 3)));

    final moon = MoonProvider(clock: () => at, southernHemisphere: true);

    await tester.pumpWidget(TestScope(
        overrides: [
          playlistProvider.overrideWith((ref) => PlaylistProvider()),
          libraryProvider.overrideWith((ref) => LibraryProvider()),
          moonProvider.overrideWith((ref) => moon, disposeNotifier: false),
          playHistoryProvider.overrideWith((ref) => history, disposeNotifier: false),
        ],
        child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: Center(child: MoonButton()))),
    )));

    await tester.tap(find.byType(MoonButton));
    await tester.pumpAndSettle();

    expect(find.text('Luna llena'), findsWidgets);
    expect(find.text('MIX DE LUNA LLENA'), findsOneWidget);
    expect(find.text('REPRODUCIR'), findsOneWidget);
    expect(find.textContaining('canciones más escuchadas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    moon.dispose();
  });

  test('mix uses the lunar month before the full moon and tops up from the library', () async {
    final at = DateTime.utc(2026, 10, 26, 3);
    final history = PlayHistory();
    await history.record(_t('recent'), at: at.subtract(const Duration(days: 5)));
    await history.record(_t('lastCycle'), at: at.subtract(const Duration(days: 40)));
    final library = LibraryProvider();

    final mix = MoonSheet.buildMix(MoonCalculator.snapshot(at), history, library);
    expect(mix.first.id, 'recent');
    expect(mix.any((t) => t.id == 'lastCycle'), isFalse);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => setState(() => n++), child: Text('$n')),
        ),
      );
}
