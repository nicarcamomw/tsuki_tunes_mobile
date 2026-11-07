import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/ambient_sound_generator.dart';
import 'package:tsuki_tunes_mobile/domain/lore/tsuki_lore.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/ascension_screen.dart';
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
      expect(TsukiLore.tomoOpen(2, 9), isFalse);
      expect(TsukiLore.tomoOpen(2, 10), isTrue);
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

    test('an Observer (a guest) has no levels: nothing opens, nothing is announced', () {
      masks.observer = true;
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      masks.onPlayCounted(_t('a${n++}'));
      expect(masks.isObserver, isTrue);
      expect(masks.level, 1);
      expect(masks.hasFeature(EcoFeature.lyrics), isFalse);
      expect(masks.choicePending, isFalse);
      expect(masks.pendingLevelUp, isNull);
      // Signing in makes them a Bearer: the levels count again.
      masks.observer = false;
      expect(masks.level, EcoLevels.maxLevel);
      expect(masks.hasFeature(EcoFeature.lyrics), isTrue);
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

    test('level 100 asks for the choice; to be makes the Bearer ethereal, with their own mask', () async {
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      expect(masks.level, EcoLevels.maxLevel);
      expect(masks.choicePending, isTrue);
      expect(masks.rank, EcoRank.vidente, reason: 'a Seer until the choice');
      expect(masks.isUnlocked('portador'), isFalse);

      await masks.chooseEthereal(ser: true, maskName: 'Luz');
      expect(masks.etherealChoice, EtherealChoice.ser);
      expect(masks.rank, EcoRank.etereo);
      expect(masks.isUnlocked('portador'), isTrue);
      expect(masks.counterValue('ultra'), 0, reason: 'not one of the eight Ultras');
      expect(masks.choicePending, isFalse);

      // Made once: it can't be changed.
      await masks.chooseEthereal(ser: false);
      expect(masks.etherealChoice, EtherealChoice.ser);
    });

    test('not to be keeps the Bearer for good, an immeasurable one', () async {
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      await masks.chooseEthereal(ser: false);
      expect(masks.etherealChoice, EtherealChoice.noSer);
      expect(masks.rank, EcoRank.inconmensurable);
      expect(masks.isUnlocked('portador'), isFalse);

      // The choice survives a restart.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final again = MaskProvider(clock: () => now);
      await again.ready;
      expect(again.etherealChoice, EtherealChoice.noSer);
      expect(again.choicePending, isFalse);
      again.dispose();
    });

    test('below level 100 there is no choice to make', () async {
      masks.applyProgress({'plays': 1000});
      expect(masks.choicePending, isFalse);
      await masks.chooseEthereal(ser: true);
      expect(masks.etherealChoice, isNull);
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

    testWidgets('level 100: to not be warns first, then keeps the Bearer', (tester) async {
      await tester.runAsync(() => masks.ready);
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      await pump(tester, const AscensionScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('La Luna Madre se regocija con tu Eco.'), findsOneWidget);
      expect(find.text('UN SER ETÉREO'), findsOneWidget);

      await tester.tap(find.text('NO SER'));
      await tester.pumpAndSettle();
      expect(find.text('ADVERTENCIA'), findsOneWidget);
      expect(find.textContaining('no podrás transformarte nunca más'), findsOneWidget);
      await tester.tap(find.text('Mantener mi forma'));
      await tester.pumpAndSettle();
      expect(masks.etherealChoice, EtherealChoice.noSer);
      expect(find.textContaining('Sigues siendo Portador'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });

    testWidgets('level 100: to be names the mask and crosses', (tester) async {
      await tester.runAsync(() => masks.ready);
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      await pump(tester, const AscensionScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('SER'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo se llamará tu máscara etérea?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Luz de Tsuki');
      await tester.tap(find.text('CRUZAR'));
      // The ethereal mask shimmers forever: step the clock instead.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(masks.etherealChoice, EtherealChoice.ser);
      expect(masks.isUnlocked('portador'), isTrue);
      expect(find.textContaining('Has traspasado la muralla'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      masks.dispose();
    });

    testWidgets('past level 100 the Eco of a god is unknown: ???????', (tester) async {
      await tester.runAsync(() => masks.ready);
      masks.applyProgress({'plays': EcoLevels.ecoFor(100) ~/ MaskProvider.ecoPerPlay});
      await pump(tester, const Scaffold(body: EcoLevelCard()));
      expect(find.textContaining('/ ??????? Eco'), findsOneWidget);
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
