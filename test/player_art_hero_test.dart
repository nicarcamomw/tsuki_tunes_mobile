import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/player_art_hero.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/rinnegan_visualizer.dart';

/// The flight frozen at [t], in a [size] square.
Widget _flightAt(double t, double size, {double rotation = 0}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.square(
          dimension: size,
          child: PlayerArtFlight(animation: AlwaysStoppedAnimation(t), coverUrl: '', rotation: rotation),
        ),
      ),
    );

Size _coverSize(WidgetTester tester) => tester.getSize(find.byType(ClipRRect));
double _coverRadius(WidgetTester tester) =>
    (tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius as BorderRadius).topLeft.x;
double _discOpacity(WidgetTester tester) => tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  testWidgets('it leaves as the mini player\'s square cover', (tester) async {
    await tester.pumpWidget(_flightAt(0, 44));
    expect(_coverSize(tester), const Size(44, 44));
    expect(_coverRadius(tester), PlayerArtFlight.miniRadius);
    expect(_discOpacity(tester), 0);
  });

  testWidgets('it lands as the expanded player\'s disc', (tester) async {
    await tester.pumpWidget(_flightAt(1, 280));
    const cover = 280 * RinneganVisualizer.coverFraction;
    expect(_coverSize(tester), const Size(cover, cover));
    expect(_coverRadius(tester), cover / 2); // round
    expect(_discOpacity(tester), 1);
  });

  testWidgets('halfway it is between the two', (tester) async {
    await tester.pumpWidget(_flightAt(0.5, 160));
    final cover = _coverSize(tester).width;
    expect(cover, lessThan(160));
    expect(cover, greaterThan(160 * RinneganVisualizer.coverFraction));
    expect(_coverRadius(tester), inExclusiveRange(PlayerArtFlight.miniRadius, cover / 2));
  });

  testWidgets('closing, the disc unwinds from its angle to upright', (tester) async {
    double angleAt(double t) {
      final m = tester.widget<Transform>(find.byType(Transform)).transform;
      return m.entry(1, 0); // sin(angle)
    }

    await tester.pumpWidget(_flightAt(1, 280, rotation: 1.0));
    expect(angleAt(1), closeTo(0.8415, 0.001)); // sin(1)
    await tester.pumpWidget(_flightAt(0, 44, rotation: 1.0));
    expect(angleAt(0), closeTo(0, 0.001));
  });

  testWidgets('the cover flies between the players with its own flight', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    const discKey = Key('disc');
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(
        body: Align(
          alignment: Alignment.bottomLeft,
          child: PlayerArtHero(
            trackId: 't1',
            coverUrl: '',
            isPlaying: true,
            child: SizedBox.square(dimension: 44),
          ),
        ),
      ),
    ));

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        body: Center(
          child: PlayerArtHero(
            trackId: 't1',
            coverUrl: '',
            isPlaying: true,
            child: SizedBox.square(key: discKey, dimension: 280),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Mid-flight: the morph flies, not the expanded player's widget.
    expect(find.byType(PlayerArtFlight), findsOneWidget);
    final flying = tester.getSize(find.byType(PlayerArtFlight));
    expect(flying.width, inExclusiveRange(44, 280));

    await tester.pumpAndSettle();
    expect(find.byType(PlayerArtFlight), findsNothing);
    expect(tester.getSize(find.byKey(discKey)), const Size(280, 280));

    // And back.
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(PlayerArtFlight), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerArtFlight), findsNothing);
  });

  testWidgets('without a disc under it the angle is 0', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    expect(RinneganVisualizer.rotationIn(ctx), 0);
  });
}
