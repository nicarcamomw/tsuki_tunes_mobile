import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/repositories/profile_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/social_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/social.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/bonds_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/social_controller.dart';

import 'helpers/fake_firebase_service.dart';
import 'helpers/test_scope.dart';

void main() {
  late FakeFirebaseFirestore db;

  SocialController controller({String? uid = 'me'}) => SocialController(
        repository: SocialRepositoryImpl(FakeFirebaseService(db)),
        profiles: ProfileRepositoryImpl(FakeFirebaseService(db)),
        changes: ChangeNotifier(),
        uid: () => uid,
        myCard: () => uid == null ? null : SocialPerson(uid: uid, name: 'Nico'),
        myTops: () => const [],
      );

  Future<void> open(WidgetTester tester, SocialController social, {int tab = 1}) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestScope(
      overrides: [socialProvider.overrideWith((ref) => social)],
      child: MaterialApp(home: BondsScreen(initialTab: tab)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() => db = FakeFirebaseFirestore());

  testWidgets('requests, Bonds and sent requests, each with its action, fit on a small phone', (tester) async {
    final at = DateTime(2026, 11, 7);
    await db.doc('users/me/friendRequests/alice').set({'name': 'Alice con un nombre bastante largo', 'at': at});
    await db.doc('users/me/friends/carol').set({'name': 'Carol', 'at': at});
    await db.doc('users/me/sentRequests/dave').set({'name': 'Dave', 'at': at});
    final social = controller();
    await open(tester, social);

    expect(find.text('SOLICITUDES · 1'), findsOneWidget);
    expect(find.text('TUS LAZOS · 1'), findsOneWidget);
    expect(find.text('ENVIADAS · 1'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Solicitud enviada'), findsOneWidget);
    // The badge on the tab: one request waiting.
    expect(find.text('1'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Aceptar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('TUS LAZOS · 2'), findsOneWidget);
    expect(find.text('SOLICITUDES · 1'), findsNothing);
  });

  testWidgets('with no Bonds yet, the Resonances invite to find someone', (tester) async {
    final social = controller();
    await open(tester, social, tab: 0);
    expect(find.textContaining('Crea tu primer Lazo'), findsOneWidget);
    await tester.tap(find.text('Crear Lazo'));
    await tester.pumpAndSettle();
    expect(find.text('Busca un Portador por su nombre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Observer is offered to become a Bearer instead', (tester) async {
    final social = controller(uid: null);
    await open(tester, social);
    expect(find.textContaining('Los Observadores no crean Lazos'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
}
