import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/error_state.dart';

import 'helpers/test_scope.dart';

// U3: the one "it failed, try again" every screen shows.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(Widget child) => TestScope(child: MaterialApp(home: Scaffold(body: child)));

  testWidgets('says what failed and tries again', (tester) async {
    var retries = 0;
    await tester.pumpWidget(app(ErrorState(message: 'No se pudo cargar', onRetry: () => retries++)));
    expect(find.text('No se pudo cargar'), findsOneWidget);
    await tester.tap(find.text('REINTENTAR'));
    expect(retries, 1);
  });

  testWidgets('without a retry there is no button', (tester) async {
    await tester.pumpWidget(app(const ErrorState(message: 'Nada por aquí')));
    expect(find.text('REINTENTAR'), findsNothing);
  });

  testWidgets('the button is 48 px to tap and is read as one', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(ErrorState(message: 'No se pudo cargar', onRetry: () {})));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.bySemanticsLabel('REINTENTAR'), findsOneWidget);
    handle.dispose();
  });
}
