import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/search_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/search_provider.dart';

import 'helpers/test_scope.dart';

/// Deezer as the search screen sees it: two genres, and nothing found.
final _deezer = MockClient((req) async {
  // Anything else (the fonts) fails as it does in every widget test.
  if (req.url.host != 'api.deezer.com') return http.Response('', 400);
  if (req.url.path == '/genre') {
    return http.Response(
        '{"data":[{"id":0,"name":"Todos"},{"id":116,"name":"Rap/Hip Hop"},'
        '{"id":152,"name":"Rock"}]}',
        200);
  }
  return http.Response('{"data":[]}', 200);
});

void main() {
  Future<void> pumpSearch(WidgetTester tester) async {
    // Wider than a phone: the test font draws every letter as a square, so
    // the "BUSCAR // 02" title would not fit 360 (real fonts do).
    tester.view.physicalSize = const Size(420 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          audioProvider.overrideWith((ref) => AudioProvider()),
          searchProvider.overrideWith(
              (ref) => SearchProvider(fuzzyArtistNames: (_) async => const [])),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ));
      // Fake time: the fake Deezer answers, the font requests never do.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }, () => _deezer);
  }

  testWidgets('the empty search offers recent searches and genres to explore',
      (tester) async {
    SharedPreferences.setMockInitialValues({'search_history': ['metallica']});
    await pumpSearch(tester);

    expect(find.text('metallica'), findsOneWidget);
    expect(find.text('EXPLORAR GÉNEROS'), findsOneWidget);
    expect(find.text('Rap/Hip Hop'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Todos'), findsNothing, reason: '"All" is not a genre to explore');
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing suggests recent searches; a tap searches it',
      (tester) async {
    SharedPreferences.setMockInitialValues({'search_history': ['metallica', 'bad bunny']});
    await pumpSearch(tester);

    await tester.showKeyboard(find.byType(TextField));
    await http.runWithClient(() async {
      await tester.enterText(find.byType(TextField), 'met');
      await tester.pump();
    }, () => _deezer);

    final chip = find.bySemanticsLabel('Buscar metallica');
    expect(chip, findsOneWidget);
    expect(find.bySemanticsLabel('Buscar bad bunny'), findsNothing);

    await http.runWithClient(() async {
      await tester.tap(chip);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }, () => _deezer);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'metallica');
    expect(tester.takeException(), isNull);

    // Let the debounce timer of the typing run out.
    await tester.pump(const Duration(milliseconds: 500));
  });
}
