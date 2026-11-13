import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/profile_bottom_sheet.dart';

import 'helpers/test_scope.dart';

// S-01 / S-03: settings open as a page, and a switch flips on its own
// (without redrawing its section).

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  testWidgets('the settings page opens and its switches flip', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          audioProvider.overrideWith((ref) => AudioProvider()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => ProfileBottomSheet.show(context, ref.read(authProvider)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A page with its title, not a sheet.
      expect(find.text('PERFIL // SISTEMA'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final tile = find.widgetWithText(SwitchListTile, 'Marcar al escuchar');
      expect(tile, findsOneWidget);
      final before = tester.widget<SwitchListTile>(tile).value;
      await tester.tap(tile);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(tile).value, !before);
      expect(tester.takeException(), isNull);
    }, () => _noNetwork);
  });
}
