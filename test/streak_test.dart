import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/streak_reminder.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/streak_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/streak_card.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late MaskProvider masks;
  var n = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 2, 15); // a Monday afternoon
    masks = MaskProvider(clock: () => now);
    await masks.ready;
  });

  tearDown(() => masks.dispose());

  void playOn(int day) {
    now = DateTime(2026, 11, 2 + day, 15);
    masks.onPlayCounted(_t('s${n++}'));
  }

  group('daily streak', () {
    test('days in a row count; today is done, tomorrow at risk, then lost', () {
      expect(masks.streakState, StreakState.none);
      for (var d = 0; d < 3; d++) {
        playOn(d);
      }
      expect(masks.dayStreak, 3);
      expect(masks.streakState, StreakState.done);

      now = DateTime(2026, 11, 5, 10);
      expect(masks.streakState, StreakState.atRisk);
      expect(masks.dayStreak, 3);

      now = DateTime(2026, 11, 6, 10);
      expect(masks.streakState, StreakState.lost);
      expect(masks.dayStreak, 0);
      expect(masks.bestStreak, 3);
    });

    test('two plays the same day count once', () {
      playOn(0);
      playOn(0);
      expect(masks.dayStreak, 1);
    });

    test('a week in a row earns a moon shield, and it covers a missed day', () {
      for (var d = 0; d < MaskProvider.shieldEvery; d++) {
        playOn(d);
      }
      expect(masks.shields, 1);

      // Day 7 missed: on day 8 the run is still alive, covered.
      now = DateTime(2026, 11, 2 + 8, 10);
      expect(masks.streakState, StreakState.shielded);
      expect(masks.dayStreak, MaskProvider.shieldEvery);

      playOn(8);
      expect(masks.dayStreak, MaskProvider.shieldEvery + 1);
      expect(masks.shields, 0);
      final day7 = masks.todayEpoch - 1;
      expect(masks.shieldedOn(day7), isTrue);
      expect(masks.playedOn(day7), isFalse);
    });

    test('with no shield, a missed day starts over', () {
      playOn(0);
      playOn(1);
      playOn(3);
      expect(masks.dayStreak, 1);
      expect(masks.bestStreak, 2);
    });

    test('shields stop at the maximum', () {
      for (var d = 0; d < MaskProvider.shieldEvery * (MaskProvider.maxShields + 1); d++) {
        playOn(d);
      }
      expect(masks.shields, MaskProvider.maxShields);
    });

    test('the streak, its shields and its days survive a restart', () async {
      for (var d = 0; d < MaskProvider.shieldEvery; d++) {
        playOn(d);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final again = MaskProvider(clock: () => now);
      await again.ready;
      expect(again.dayStreak, MaskProvider.shieldEvery);
      expect(again.shields, 1);
      expect(again.playedOn(again.todayEpoch), isTrue);
      again.dispose();
    });
  });

  group('reminder', () {
    // Epoch day of 2026-11-02 (local dates).
    final monday = DateTime.utc(2026, 11, 2).millisecondsSinceEpoch ~/ 86400000;

    test('the evening of the first day without music', () {
      expect(
        StreakReminder.remindAt(streak: 3, lastDay: monday, now: DateTime(2026, 11, 2, 15)),
        DateTime(2026, 11, 3, StreakReminder.hour),
      );
    });

    test('none for a run too short, or once that evening has passed', () {
      expect(StreakReminder.remindAt(streak: 1, lastDay: monday, now: DateTime(2026, 11, 2, 15)), isNull);
      expect(StreakReminder.remindAt(streak: 5, lastDay: monday, now: DateTime(2026, 11, 3, 21)), isNull);
    });

    test('the provider gives the run to remind, and nothing once it is out', () {
      playOn(0);
      playOn(1);
      expect(masks.streakForReminder, (streak: 2, lastDay: masks.todayEpoch));
      now = DateTime(2026, 11, 10, 10);
      expect(masks.streakForReminder, isNull);
    });
  });

  group('screens', () {
    Future<void> pumpIn(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TestScope(
        overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
        child: MaterialApp(home: child),
      ));
      await tester.pump();
    }

    testWidgets('Home shows the run and opens the streak screen', (tester) async {
      for (var d = 0; d < 4; d++) {
        playOn(d);
      }
      await pumpIn(tester, const Scaffold(body: StreakCard()));
      expect(tester.takeException(), isNull);
      expect(find.text('RACHA · 4 DÍAS'), findsOneWidget);
      expect(find.text('Hoy ya sumaste ✓'), findsOneWidget);

      await tester.tap(find.byType(StreakCard));
      await tester.pumpAndSettle();
      expect(find.byType(StreakScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the streak screen: stats, calendar, goals with their masks, shields, reminder', (tester) async {
      for (var d = 0; d < 8; d++) {
        playOn(d);
      }
      await pumpIn(tester, const StreakScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('MEJOR RACHA'), findsOneWidget);
      expect(find.text('ÚLTIMAS 5 SEMANAS'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('ESCUDO LUNAR'), 300);
      expect(find.text('Lograda'), findsWidgets);
      // The 7-day goal wakes a mask, and shows it.
      final weekMask = MaskCatalog.all.firstWhere((m) => m.counter == 'streak' && m.goal == 7);
      expect(find.textContaining(weekMask.names.values.first), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Recordatorio suave'), 300);
      expect(find.byType(Switch), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
