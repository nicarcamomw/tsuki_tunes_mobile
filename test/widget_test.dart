import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/widgets/oni_mask_icon.dart';

void main() {
  testWidgets('OniMaskIcon renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OniMaskIcon(isActive: true, size: 24),
        ),
      ),
    );
    expect(find.byType(OniMaskIcon), findsOneWidget);
  });
}
