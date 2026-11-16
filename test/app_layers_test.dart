import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/celebration.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/connection_notice.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/frosted_glass.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mask_unlock_banner.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/moon_atmosphere.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/sakura_overlay.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/witching_hour_overlay.dart';

import 'helpers/test_scope.dart';

// The layers over the whole app: a mask woken, a level, a birthday, the
// witching hour, and the moon's light.

OniMask _first(bool Function(OniMask) test) => MaskCatalog.all.firstWhere(test);

/// Music playing (or not), for the witching hour.
class _Audio extends AudioProvider {
  _Audio(this.playing);
  final bool playing;
  @override
  bool get isPlaying => playing;
}

void main() {
  late MaskProvider masks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectionNotice.visible.value = false;
  });

  Future<void> pumpLayer(WidgetTester tester, {VoidCallback? onOpen, bool still = false}) async {
    masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestScope(
      overrides: [maskProvider.overrideWith((ref) => masks, disposeNotifier: false)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: child!,
        ),
        home: MaskUnlockLayer(onOpenCollection: onOpen, child: const Scaffold(body: SizedBox.expand())),
      ),
    ));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    masks.dispose();
  }

  group('a mask woken', () {
    testWidgets('R / SR: a capsule of glass whose title reads (AA) even in SR\'s violet', (tester) async {
      await pumpLayer(tester);
      final sr = _first((m) => m.rarity == MaskRarity.sr && !m.secret);
      masks.unlock(sr.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final overline = find.textContaining('SER ETÉREO DESPIERTO');
      expect(overline, findsOneWidget);
      expect(find.ancestor(of: overline, matching: find.byType(FrostedGlass)), findsOneWidget);
      final color = tester.widget<Text>(overline).style!.color!;
      expect(contrastRatio(color.withValues(alpha: 1), AppColors.bgDeep), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(const Color(0xFFB026FF), AppColors.bgDeep), lessThan(4.5), reason: 'the violet as it was didn\'t');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await finish(tester);
    });

    testWidgets('a finger held on it keeps it; let go, it leaves after a moment', (tester) async {
      await pumpLayer(tester);
      final mask = _first((m) => m.rarity == MaskRarity.r && !m.secret);
      masks.unlock(mask.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final title = find.textContaining(mask.name(AppLanguage.es));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(CelebrationBanner)));
      await tester.pump(const Duration(seconds: 15));
      expect(title, findsOneWidget, reason: 'held: still there');
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(masks.pendingCelebration, isNot(mask.id));
      await finish(tester);
    });

    testWidgets('it sits below the connection pill when that shows', (tester) async {
      await pumpLayer(tester);
      masks.unlock(_first((m) => m.rarity == MaskRarity.r && !m.secret).id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final glass = find.descendant(of: find.byType(CelebrationBanner), matching: find.byType(FrostedGlass));
      final top = tester.getTopLeft(glass).dy;
      ConnectionNotice.visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getTopLeft(glass).dy, closeTo(top + ConnectionNotice.clearance, 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await finish(tester);
    });

    testWidgets('SSR: a sheen of light crosses the mask', (tester) async {
      await pumpLayer(tester);
      masks.unlock(_first((m) => m.rarity == MaskRarity.ssr && !m.secret).id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.descendant(of: find.byType(CelebrationBanner), matching: find.byType(ShaderMask)), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await finish(tester);
    });

    testWidgets('UL: the whole screen, the mask in its light; it goes by itself, or a tap opens the collection', (tester) async {
      var opened = 0;
      await pumpLayer(tester, onOpen: () => opened++);
      final ul = _first((m) => m.rarity == MaskRarity.ul && !m.divine && !m.chosen);
      masks.unlock(ul.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(GrandUnlock), findsOneWidget);
      expect(find.byType(CelebrationBanner), findsNothing);
      expect(find.text('Toca para verla en tu colección'), findsOneWidget);
      expect(tester.getSize(find.byType(GrandUnlock)), const Size(400, 860));

      await tester.tap(find.byType(GrandUnlock));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(masks.pendingCelebration, isNull);
      await finish(tester);
    });

    testWidgets('the one from another universe is announced as such, in its own cold light', (tester) async {
      await pumpLayer(tester);
      masks.unlock('ikai');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('DE OTRO UNIVERSO'), findsOneWidget);
      expect(unlockColor(MaskCatalog.byId('ikai')!), const Color(0xFFC9D1DB));
      await tester.pump(GrandUnlock.stay);
      await tester.pumpAndSettle();
      expect(find.byType(GrandUnlock), findsNothing);
      await finish(tester);
    });
  });

  test('a celebration stays as long as it takes to read, twice that with TalkBack', () {
    expect(readingTime('Hola'), const Duration(milliseconds: 4500));
    final long = readingTime('x' * 200);
    expect(long, const Duration(milliseconds: 9000));
    final mid = readingTime('x' * 60);
    expect(mid, greaterThan(readingTime('x' * 20)));
    expect(readingTime('x' * 60, talkBack: true), mid * 2);
  });

  group('the birthday', () {
    final today = DateTime(2026, 4, 7);

    Future<void> pumpSakura(WidgetTester tester, {bool still = false}) async {
      tester.view.physicalSize = const Size(400 * 2, 860 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TestScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: Scaffold(body: SakuraOverlay(today: today)),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    bool raining(WidgetTester tester) => find
        .byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_SakuraPainter')
        .evaluate()
        .isNotEmpty;

    testWidgets('a short rain under a greeting the first time that day, then nothing more', (tester) async {
      SharedPreferences.setMockInitialValues({SakuraOverlay.birthdayKey: '04-07'});
      await pumpSakura(tester);
      expect(find.text('Feliz cumpleaños'), findsOneWidget);
      expect(raining(tester), isTrue);

      // The rain ends (its ticker with it), then the greeting.
      await tester.pump(SakuraOverlay.burst);
      await tester.pump();
      expect(raining(tester), isFalse);
      await tester.pump(SakuraOverlay.greetingAfter);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Feliz cumpleaños'), matching: find.byType(AnimatedOpacity))).opacity, 0);
      expect(tester.hasRunningAnimations, isFalse);

      // Opened again the same day: once is enough.
      await tester.pumpWidget(const SizedBox());
      await pumpSakura(tester);
      expect(raining(tester), isFalse);
    });

    testWidgets('tapping the greeting brings the rain again', (tester) async {
      SharedPreferences.setMockInitialValues({SakuraOverlay.birthdayKey: '04-07'});
      await pumpSakura(tester);
      await tester.pump(SakuraOverlay.burst);
      await tester.pump();
      expect(raining(tester), isFalse);
      await tester.tap(find.text('Feliz cumpleaños'));
      await tester.pump();
      expect(raining(tester), isTrue);
      await tester.pump(SakuraOverlay.burst);
      await tester.pump(SakuraOverlay.greetingAfter);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('with less motion: the greeting alone, no petals', (tester) async {
      SharedPreferences.setMockInitialValues({SakuraOverlay.birthdayKey: '04-07'});
      await pumpSakura(tester, still: true);
      expect(find.text('Feliz cumpleaños'), findsOneWidget);
      expect(raining(tester), isFalse);
      await tester.pump(SakuraOverlay.greetingAfter * 2);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('another day: nothing', (tester) async {
      SharedPreferences.setMockInitialValues({SakuraOverlay.birthdayKey: '12-24'});
      await pumpSakura(tester);
      expect(raining(tester), isFalse);
      expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Feliz cumpleaños'), matching: find.byType(AnimatedOpacity))).opacity, 0);
    });
  });

  group('the witching hour', () {
    Future<void> pumpWitching(WidgetTester tester, {required DateTime at, bool playing = true, bool still = false}) async {
      await tester.pumpWidget(TestScope(
        overrides: [audioProvider.overrideWith((ref) => _Audio(playing))],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: Scaffold(body: WitchingHourOverlay(clock: () => at)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('3:33 with music: a whisper in the Lore\'s voice, told to TalkBack, then gone', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWitching(tester, at: DateTime(2026, 11, 15, 3, 33));
      expect(find.text('La hora en que el velo se adelgaza…'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('La hora en que el velo se adelgaza…'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      await tester.pump(WitchingHourOverlay.length);
      await tester.pump();
      expect(find.text('La hora en que el velo se adelgaza…'), findsNothing);
      handle.dispose();
    });

    testWidgets('with less motion it still comes, still: no glitch', (tester) async {
      await pumpWitching(tester, at: DateTime(2026, 11, 15, 3, 33), still: true);
      expect(find.text('La hora en que el velo se adelgaza…'), findsOneWidget);
      await tester.pump(WitchingHourOverlay.length);
      await tester.pump();
    });

    testWidgets('silent, or any other minute: nothing', (tester) async {
      await pumpWitching(tester, at: DateTime(2026, 11, 15, 3, 33), playing: false);
      expect(find.text('La hora en que el velo se adelgaza…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpWitching(tester, at: DateTime(2026, 11, 15, 3, 34));
      expect(find.text('La hora en que el velo se adelgaza…'), findsNothing);
    });
  });

  group('the moon\'s light keeps the text readable (AA)', () {
    Color under(Color c, Color over, double a) => Color.lerp(c, over, a)!;
    const black = Color(0xFF000000);
    final texts = [AppColors.textMuted, AppColors.textSecondary, AppColors.textPrimary];

    test('at new moon, at the darkened edges', () {
      const dim = MoonlightPainter.maxDim + MoonlightPainter.vignetteBase + MoonlightPainter.vignetteDark;
      for (final t in texts) {
        expect(contrastRatio(under(t, black, dim), under(AppColors.bgDeep, black, dim)), greaterThanOrEqualTo(4.5), reason: '$t');
      }
    });

    test('in the full moon\'s silver light', () {
      const silver = Color(0xFFD6E0F5);
      for (final t in texts) {
        expect(contrastRatio(under(t, silver, MoonlightPainter.maxSilver), under(AppColors.bgDeep, silver, MoonlightPainter.maxSilver)),
            greaterThanOrEqualTo(4.5),
            reason: '$t');
      }
    });
  });
}
