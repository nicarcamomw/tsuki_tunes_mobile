import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tsuki_tunes_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows the home screen', (tester) async {
    app.main();
    // Let Firebase init and the first frame settle.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // The app should have rendered something — at minimum, a Material scaffold.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
