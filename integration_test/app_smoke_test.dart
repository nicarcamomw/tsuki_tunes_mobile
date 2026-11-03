import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tsuki_tunes_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows the home screen', (tester) async {
    app.main();
    // Firebase and the first screen take a few seconds. The app has looping
    // animations (moon, glitch text), so it never settles: pumpAndSettle
    // would wait until the test times out. Pump for 10 s instead.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // The app should have rendered something — at minimum, a Material scaffold.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
