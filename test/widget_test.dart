import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/oni_mask_icon.dart';

import 'helpers/test_scope.dart';

void main() {
  testWidgets('OniMaskIcon renders correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      TestScope(
        overrides: [maskProvider.overrideWith((ref) => MaskProvider())],
        child: const MaterialApp(
          home: Scaffold(
            body: OniMaskIcon(isActive: true, size: 24),
          ),
        ),
      ),
    );
    expect(find.byType(OniMaskIcon), findsOneWidget);
  });
}
