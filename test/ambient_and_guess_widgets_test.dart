import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/ambient_provider.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/locale_provider.dart';
import 'package:tsuki_tunes_mobile/screens/guess_song_screen.dart';
import 'package:tsuki_tunes_mobile/widgets/ambient_mixer_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, {AmbientProvider? ambient}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ambient ?? AmbientProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
      ],
      child: MaterialApp(home: child),
    );
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
    expect(find.text('Top mundial'), findsOneWidget);
    expect(find.text('No se pudo cargar la canción'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();
    expect(find.text('INTENTOS PARA ADIVINAR'), findsOneWidget);
  });
}
