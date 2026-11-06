import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/weekly_challenges_card.dart';

import 'helpers/test_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final compact in [false, true]) {
    testWidgets('the week\'s challenges and both prizes fit a narrow phone${compact ? ' (Home)' : ''}',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
      await tester.runAsync(() => masks.ready);

      await tester.pumpWidget(TestScope(
        overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: WeeklyChallengesCard(compact: compact))),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final theme = masks.weeklyTheme!;
      if (!compact) {
        // The themed challenge, in words, and the two prizes.
        expect(find.textContaining('canciones de'), findsOneWidget);
        expect(find.textContaining('2 desafíos: «'), findsOneWidget);
        expect(find.textContaining('3 desafíos: «'), findsOneWidget);
        expect(find.text('2/3 · R'), findsOneWidget);
        expect(find.text('3/3 · SR'), findsOneWidget);
      }
      expect(theme, isNotNull);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });
  }
}
