import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/data/datasources/bpm_flow.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_art_hero.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/rinnegan_visualizer.dart';

import 'helpers/test_scope.dart';

// The disc takes the player's colour (the song's, the palette's, an aura or
// the base red), like the play button and the bar, not a fixed red.

const _purple = Color(0xFF8B44C9);

/// The colours of every circle's border drawn under [of].
Set<Color> _borders(WidgetTester tester, Finder of) => {
      for (final w in tester.widgetList(find.descendant(of: of, matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox))))
        if (w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).border is Border)
          ((w.decoration! as BoxDecoration).border! as Border).top.color
        else if (w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border is Border)
          ((w.decoration as BoxDecoration).border! as Border).top.color,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
  });

  testWidgets('the disc is drawn in the player\'s colour', (tester) async {
    final tempo = BpmService(fetch: (_) async => const TrackAudioInfo(bpm: 120), gap: Duration.zero);
    await tester.pumpWidget(TestScope(
      overrides: [bpmProvider.overrideWithValue(tempo)],
      child: MaterialApp(
        home: Scaffold(
          body: PlayerTint(
            color: _purple,
            child: Center(
              child: RinneganVisualizer(
                isPlaying: true,
                size: 260,
                trackId: 'song',
                position: () => Duration.zero,
                speed: () => 1.0,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final colours = _borders(tester, find.byType(RinneganVisualizer));
    expect(colours, contains(_purple));
    expect(colours, isNot(contains(AppColors.accent)), reason: 'no red left on it');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the cover flying to the disc lands in that colour too', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: PlayerTint(
        color: _purple,
        child: Center(
          child: SizedBox.square(
            dimension: 280,
            child: PlayerArtFlight(animation: AlwaysStoppedAnimation(1), coverUrl: '', isPlaying: true),
          ),
        ),
      ),
    ));
    expect(_borders(tester, find.byType(PlayerArtFlight)), contains(_purple));
  });
}
