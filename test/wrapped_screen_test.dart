import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/wrapped_data.dart';
import 'package:tsuki_tunes_mobile/screens/wrapped_screen.dart';
import 'helpers/test_scope.dart';

WrappedData _data({int? month}) => WrappedData(
      year: 2026,
      month: month,
      activeDays: 20,
      periodDays: 30,
      previousMinutes: 1000,
      topTracks: const [
        WrappedTrackEntry(trackId: '1', title: 'Chop Suey!', artistName: 'SOAD', albumTitle: '', coverUrl: '', playCount: 40, totalSeconds: 8000),
        WrappedTrackEntry(trackId: '2', title: 'Cirice', artistName: 'Ghost', albumTitle: '', coverUrl: '', playCount: 30, totalSeconds: 8000),
      ],
      topArtists: const [
        WrappedArtistEntry(name: 'SOAD', playCount: 90, totalSeconds: 18000),
        WrappedArtistEntry(name: 'Ghost', playCount: 50, totalSeconds: 10000),
      ],
      totalMinutesListened: 1500,
      totalTracksPlayed: 400,
      uniqueTracksCount: 120,
      uniqueArtistsCount: 40,
      favoriteHour: 22,
      hourDistribution: const {22: 50, 14: 10},
      funFacts: const [WrappedFunFact(key: 'night_owl', data: {'percentage': 60})],
      generatedAt: DateTime(2026, 10, 30),
      basedOnPlays: true,
      playsSince: DateTime(2026, 1, 1),
    );

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, WrappedData data) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestScope(
        child: MaterialApp(
        home: WrappedScreen(year: data.year, month: data.month, previewData: data),
      ),
    ));
    await tester.pump();
    await frames(tester);
  }

  testWidgets('a monthly recap goes through every slide to the summary',
      (tester) async {
    await pump(tester, _data(month: 10));
    expect(find.text('WRAPPED'), findsOneWidget);
    expect(find.text('OCTUBRE 2026'), findsOneWidget);

    // Tap the right side to move on, eight slides in all.
    for (var i = 0; i < 7; i++) {
      await tester.tapAt(const Offset(380, 500));
      await frames(tester);
    }
    expect(find.text('COMPARTIR RESUMEN'), findsOneWidget);
    expect(find.text('NOS VEMOS EL PRÓXIMO MES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a yearly recap shows the year', (tester) async {
    await pump(tester, _data());
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('¿Listo para revivir tu año?'), findsOneWidget);
  });
}
