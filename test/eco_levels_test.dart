import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/ambient_sound_generator.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/eco_levels_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/eco_widgets.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mask_unlock_banner.dart';

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

  group('the curve', () {
    test('each level costs more than the last; the last ten far more', () {
      var lastStep = 0;
      for (var l = 2; l <= EcoLevels.maxLevel; l++) {
        final step = EcoLevels.ecoFor(l) - EcoLevels.ecoFor(l - 1);
        expect(step, greaterThan(lastStep), reason: 'level $l');
        lastStep = step;
      }
      final to90 = EcoLevels.ecoFor(90);
      expect(EcoLevels.ecoFor(100) - to90, greaterThan(to90 * 4), reason: '90 to 100 dwarfs the climb to 90');
    });

    test('Eco maps back to its level, and 100 is the top', () {
      for (var l = 1; l <= EcoLevels.maxLevel; l++) {
        expect(EcoLevels.levelFor(EcoLevels.ecoFor(l)), l);
        if (l > 1) expect(EcoLevels.levelFor(EcoLevels.ecoFor(l) - 1), l - 1);
      }
      expect(EcoLevels.levelFor(EcoLevels.legendEco * 2), EcoLevels.maxLevel);
      expect(EcoLevels.legendProgress(EcoLevels.ecoFor(100)), 0);
      expect(EcoLevels.legendProgress(EcoLevels.legendEco), 1);
    });

    test('the first levels come in the first sessions', () {
      // A first day: 20 songs, a day with music, two beings awakened.
      final firstDay = 20 * MaskProvider.ecoPerPlay + MaskProvider.ecoPerDay + 2 * 100;
      expect(EcoLevels.levelFor(firstDay), inInclusiveRange(3, 5));
    });
  });

  group('the rewards', () {
    test('every level gives something, and every fragment is told once', () {
      final told = <Object>[];
      for (var l = 1; l <= EcoLevels.maxLevel; l++) {
        final r = EcoLevels.rewardsAt(l);
        expect(r, isNotEmpty, reason: 'level $l');
        told.addAll(r.where((x) => x.fragment != null).map((x) => x.fragment!));
      }
      expect(told.length, EcoLevels.fragments.length);
      expect(told.toSet().length, told.length);
    });

    test('the ranks, the powers and the volumes sit where the legend says', () {
      expect(EcoLevels.rankOf(1), EcoRank.errante);
      expect(EcoLevels.rankOf(50), EcoRank.portador);
      expect(EcoLevels.rankOf(75), EcoRank.oyente);
      expect(EcoLevels.rankOf(90), EcoRank.vidente);
      expect(EcoLevels.rankOf(100), EcoRank.etereo);
      expect(EcoFeature.hearBeings.level, 75);
      expect(EcoFeature.seeBeings.level, 90);
      expect(EcoFeature.ethereal.level, 100);
      expect(EcoLevels.tomoOpen(2, 9), isFalse);
      expect(EcoLevels.tomoOpen(2, 10), isTrue);
      expect(EcoLevels.soundOpen(AmbientSound.rain, 7), isFalse);
      expect(EcoLevels.soundOpen(AmbientSound.rain, EcoFeature.ambient.level), isTrue);
    });
  });

  group('the account', () {
    late DateTime now;
    late MaskProvider masks;
    var n = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 11, 2, 15);
      masks = MaskProvider(clock: () => now);
      await masks.ready;
    });

    tearDown(() => masks.dispose());

    test('songs, days and beings add Eco; a day counts once', () {
      expect(masks.eco, 0);
      expect(masks.level, 1);
      masks.onPlayCounted(_t('a${n++}'));
      // A song, the day's Eco, and the first being (R).
      final afterOne = masks.eco;
      expect(afterOne, MaskProvider.ecoPerPlay + MaskProvider.ecoPerDay + MaskProvider.ecoPerStreakDay + 100);
      masks.onPlayCounted(_t('a${n++}'));
      expect(masks.eco, afterOne + MaskProvider.ecoPerPlay);
    });

    test('a new level is announced once, with what it opened', () {
      masks.onPlayCounted(_t('a${n++}'));
      final (from, to) = masks.pendingLevelUp!;
      expect(from, 1);
      expect(to, masks.level);
      expect(to, greaterThan(1));
      masks.levelUpShown();
      expect(masks.pendingLevelUp, isNull);
    });

    test('an account from before the levels starts at its level, without a party', () async {
      SharedPreferences.setMockInitialValues({'masks_stats_v1': '{"plays": 3000}'});
      final old = MaskProvider(clock: () => now);
      await old.ready;
      expect(old.level, greaterThan(20));
      expect(old.pendingLevelUp, isNull);
      old.dispose();
    });

    test('features follow the level', () {
      expect(masks.hasFeature(EcoFeature.artistRadio), isFalse);
      masks.applyProgress({'plays': 100});
      expect(masks.hasFeature(EcoFeature.artistRadio), isTrue);
      expect(masks.hasFeature(EcoFeature.hearBeings), isFalse);
    });

    test('a player colour only once its level is reached', () {
      masks.setPlayerColor('jade');
      expect(masks.playerColor, isNull);
      masks.applyProgress({'plays': 1000});
      expect(masks.playerColor?.id, 'jade');
    });

    test('level 100 makes the Bearer an ethereal being: their own mask', () {
      expect(masks.isUnlocked('portador'), isFalse);
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      masks.onPlayCounted(_t('a${n++}'));
      expect(masks.level, EcoLevels.maxLevel);
      expect(masks.isUnlocked('portador'), isTrue);
      expect(masks.counterValue('ultra'), 0, reason: 'not one of the eight Ultras');
    });
  });

  group('screens', () {
    late MaskProvider masks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      masks = MaskProvider(clock: () => DateTime(2026, 11, 2, 15));
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => masks.ready);
      await tester.pumpWidget(TestScope(
        overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
        child: MaterialApp(home: child),
      ));
      await tester.pump();
    }

    testWidgets('the levels screen: level, how to earn, colours, the 100 levels and the legend', (tester) async {
      await pump(tester, const EcoLevelsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('NIVELES DE ECO'), findsOneWidget);
      expect(find.text('CÓMO SE GANA ECO'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('LOS 100 NIVELES'), 400);
      await tester.scrollUntilVisible(find.text('NIVEL 100+ · DIOS SUPREMO'), 2000);
      expect(find.text('Nunca alcanzado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });

    testWidgets('a locked feature shows its level, and explains when tapped', (tester) async {
      await pump(
          tester,
          const Scaffold(
            body: EcoLocked(feature: EcoFeature.timeMachine, child: SizedBox(width: 200, height: 80)),
          ));
      expect(find.text('NV 15'), findsOneWidget);
      await tester.tap(find.byType(EcoLocked));
      await tester.pumpAndSettle();
      expect(find.text('SE ABRE EN EL NIVEL 15'), findsOneWidget);
      expect(find.text('Ver niveles'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });

    testWidgets('reaching a level shows its banner after the beings\' ones', (tester) async {
      await pump(tester, const MaskUnlockLayer(child: Scaffold()));
      masks.onPlayCounted(_t('x'));
      // First the being awakened, then the level.
      await tester.pump();
      expect(find.text('SER ETÉREO DESPIERTO'), findsOneWidget);
      masks.dismissCelebration();
      await tester.pump();
      expect(find.text('SUBISTE DE NIVEL'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 8));
      expect(masks.pendingLevelUp, isNull);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });
  });
}
