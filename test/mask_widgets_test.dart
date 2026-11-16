import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/mask_collection_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mask_unlock_banner.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/my_avatar.dart';

import 'helpers/test_scope.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(MaskProvider masks, Widget child) => TestScope(
        overrides: [
          maskProvider.overrideWith((ref) => masks, disposeNotifier: false),
        ],
        child: MaterialApp(home: child));

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
    expect(find.text('2 / ${MaskCatalog.all.length}'), findsOneWidget);

    await tester.tap(find.text('Cien Voces'));
    await tester.pumpAndSettle();
    expect(find.text('Escucha 250 canciones.'), findsOneWidget);
    expect(find.text('0/250'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });

  testWidgets('a mask goes on the profile from its page, and the avatar shows it instead of the photo', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    masks.unlock('hajime');
    masks.dismissCelebration();

    await tester.pumpWidget(wrap(
        masks,
        const Scaffold(
          body: Column(children: [MyAvatar(size: 60), Expanded(child: MaskCollectionScreen())]),
        )));
    await tester.pump();
    // No profile mask: no mask in the avatar (the photo, here none).
    expect(find.descendant(of: find.byType(MyAvatar), matching: find.byType(Image)), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    await tester.tap(find.text('Primer Eco').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('USAR EN MI PERFIL'));
    await tester.tap(find.text('USAR EN MI PERFIL'));
    await tester.pump();
    expect(masks.profileMask?.id, 'hajime');
    expect(find.text('QUITAR DE MI PERFIL'), findsOneWidget);
    expect(find.descendant(of: find.byType(MyAvatar), matching: find.byType(Image)), findsOneWidget);

    await tester.tap(find.text('QUITAR DE MI PERFIL'));
    await tester.pump();
    expect(masks.profileMask, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
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
    expect(find.textContaining('SER ETÉREO DESPIERTO'), findsOneWidget);
    expect(find.textContaining('Oído Absoluto'), findsOneWidget);

    // It stays as long as it takes to read, then goes.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('SER ETÉREO DESPIERTO'), findsNothing);
    expect(masks.pendingCelebration, isNull);

    await tester.pumpWidget(const SizedBox());
    masks.dispose();
  });
}
