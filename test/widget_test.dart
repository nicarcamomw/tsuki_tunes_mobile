import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/main.dart';

void main() {
  testWidgets('App launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const TsukiTunesApp());
    expect(find.byType(TsukiTunesApp), findsOneWidget);
  });
}
