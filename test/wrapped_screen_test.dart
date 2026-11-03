import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/wrapped_data.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/wrapped_screen.dart';
import 'helpers/test_scope.dart';

WrappedData _data({int? month}) => WrappedData(
  year: 2026,
  month: month,
  activeDays: 20,
  periodDays: 30,
  previousMinutes: 1000,
  topTracks: const [
    WrappedTrackEntry(
      trackId: '1',
      title: 'Chop Suey!',
      artistName: 'SOAD',
      albumTitle: '',
      coverUrl: '',
      playCount: 40,
      totalSeconds: 8000,
    ),
    WrappedTrackEntry(
      trackId: '2',
      title: 'Cirice',
      artistName: 'Ghost',
      albumTitle: '',
      coverUrl: '',
      playCount: 30,
      totalSeconds: 8000,
    ),
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
  funFacts: const [
    WrappedFunFact(key: 'night_owl', data: {'percentage': 60}),
  ],
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

  Future<void> pump(
    WidgetTester tester,
    WrappedData data, {
    Size size = const Size(1080, 2340),
    double ratio = 2.7,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestScope(
        child: MaterialApp(
          home: WrappedScreen(
            year: data.year,
            month: data.month,
            previewData: data,
          ),
        ),
      ),
    );
    await tester.pump();
    await frames(tester);
  }

  testWidgets('a monthly recap goes through every slide to the summary', (
    tester,
  ) async {
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

  for (final small in [false, true]) {
    testWidgets(
      'albums, the ones heard whole and the streak${small ? ' (small phone)' : ''}',
      (tester) async {
        const album = WrappedAlbumEntry(
          albumId: 'm',
          title: 'Mezmerize',
          artistName: 'SOAD',
          coverUrl: '',
          playCount: 60,
          trackIds: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'],
          totalTracks: 11,
        );
        final data = _data(month: 10).copyWith(
          topAlbums: const [
            album,
            WrappedAlbumEntry(
              albumId: 'i',
              title: 'Impera',
              artistName: 'Ghost',
              coverUrl: '',
              playCount: 20,
              trackIds: ['a', 'b'],
            ),
          ],
          completedAlbums: const [album],
          longestStreak: 12,
          streakStart: DateTime(2026, 10, 3),
        );
        await pump(
          tester,
          data,
          size: small ? const Size(720, 1280) : const Size(1080, 2340),
          ratio: small ? 2 : 2.7,
        );

        // Intro → minutes: the streak.
        await tester.tapAt(Offset(small ? 340 : 380, 300));
        await frames(tester);
        expect(
          find.textContaining('Racha más larga: 12 días seguidos'),
          findsOneWidget,
        );

        // → song → artist → albums.
        for (var i = 0; i < 3; i++) {
          await tester.tapAt(Offset(small ? 340 : 380, 300));
          await frames(tester);
        }
        expect(find.text('TUS ÁLBUMES'), findsOneWidget);
        expect(find.text('Mezmerize'), findsOneWidget);
        expect(find.text('ESCUCHASTE COMPLETOS'), findsOneWidget);
        expect(find.textContaining('1 álbum entero'), findsOneWidget);

        // Nine slides now; the recap card has the streak.
        for (var i = 0; i < 4; i++) {
          await tester.tapAt(Offset(small ? 340 : 380, 300));
          await frames(tester);
        }
        expect(find.text('COMPARTIR RESUMEN'), findsOneWidget);
        expect(find.text('RACHA'), findsOneWidget);
        expect(find.text('12 d'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a yearly recap shows the year', (tester) async {
    await pump(tester, _data());
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('¿Listo para revivir tu año?'), findsOneWidget);
  });
}
