import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/locale_provider.dart';
import 'package:tsuki_tunes_mobile/providers/mask_provider.dart';
import 'package:tsuki_tunes_mobile/screens/mask_collection_screen.dart';
import 'package:tsuki_tunes_mobile/widgets/mask_unlock_banner.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(MaskProvider masks, Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider.value(value: masks),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('collection hides secret masks until they are unlocked', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    masks.unlock('hajime');
    masks.unlock('sanji');
    masks.dismissCelebration();
    masks.dismissCelebration();

    await tester.pumpWidget(wrap(masks, const MaskCollectionScreen()));
    await tester.pump();

    expect(find.text('Primer Eco'), findsWidgets);
    expect(find.text('3:33'), findsOneWidget, reason: 'unlocked secret is revealed');
    expect(find.text('Noche de Hannya'), findsNothing, reason: 'locked secret stays hidden');
    expect(find.text('???'), findsNWidgets(4));
    expect(find.text('2 / 16'), findsOneWidget);

    await tester.tap(find.text('Cien Voces'));
    await tester.pumpAndSettle();
    expect(find.text('Escucha 250 canciones.'), findsOneWidget);
    expect(find.text('0/250'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });

  testWidgets('unlock banner announces a new mask and goes away', (tester) async {
    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);

    await tester.pumpWidget(wrap(
      masks,
      const MaskUnlockLayer(child: Scaffold(body: SizedBox.expand())),
    ));
    masks.unlock('mimi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('MÁSCARA DESBLOQUEADA'), findsOneWidget);
    expect(find.textContaining('Oído Absoluto'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('MÁSCARA DESBLOQUEADA'), findsNothing);
    expect(masks.pendingCelebration, isNull);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });
}
