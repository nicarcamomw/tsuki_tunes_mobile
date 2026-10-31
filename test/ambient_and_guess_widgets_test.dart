import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/ambient_provider.dart';
import 'package:tsuki_tunes_mobile/providers/app_providers.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/screens/guess_song_screen.dart';
import 'package:tsuki_tunes_mobile/widgets/ambient_mixer_sheet.dart';

import 'helpers/test_scope.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, {AmbientProvider? ambient}) {
    return TestScope(
        overrides: [
          ambientProvider.overrideWith((ref) => ambient ?? AmbientProvider()),
        ],
        child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
      ],
      child: MaterialApp(home: child),
    ));
  }

  testWidgets('ambient mixer sheet lists every sound and the timer options',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const Scaffold(body: AmbientMixerSheet())));
    await tester.pump();

    for (final name in ['Lluvia', 'Tormenta', 'Olas', 'Fogata', 'Viento', 'Noche']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Apagar con la música'), findsOneWidget);
    expect(find.text('No apagar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing what happens after the sleep timer is saved',
      (tester) async {
    final ambient = AmbientProvider();
    await tester.pumpWidget(wrap(const Scaffold(body: AmbientMixerSheet()), ambient: ambient));
    await tester.pump();

    await tester.tap(find.text('Seguir 30 min'));
    await tester.pump();

    expect(ambient.afterTimerMinutes, 30);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ambient_after_timer_minutes'), 30);
  });

  testWidgets('guess screen shows the modes and recovers from a network error',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const GuessSongScreen()));
    // flutter_test blocks real HTTP, so loading the chart fails.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('Reto diario'), findsOneWidget);
    expect(find.text('Mis canciones'), findsOneWidget);
    // The mode chips scroll sideways; the last ones start off screen.
    expect(find.text('Artista', skipOffstage: false), findsOneWidget);
    expect(find.text('Top mundial', skipOffstage: false), findsOneWidget);
    expect(find.text('No se pudo cargar la canción'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('INTENTOS PARA ADIVINAR'), findsOneWidget);
  });

  testWidgets('artist mode asks for an artist first', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryProvider()),
          ambientProvider.overrideWith((ref) => AmbientProvider()),
        ],
        child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
      ],
      child: const MaterialApp(home: GuessSongScreen()),
    )));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.ensureVisible(find.text('Artista', skipOffstage: false));
    await tester.pump();
    await tester.tap(find.text('Artista'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Elige un artista y adivina su discografía'), findsOneWidget);
    expect(find.text('Busca un artista…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
