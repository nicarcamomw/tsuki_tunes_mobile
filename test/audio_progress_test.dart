import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/audio_progress_selector.dart';
import 'helpers/test_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') {
          final id = (methodCall.arguments as Map)['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (MethodCall call) async => {},
          );
        }
        return {};
      },
    );
  });

  test('position ticks go to progressListenable, not to every listener', () {
    final audio = AudioProvider();
    var state = 0;
    var progress = 0;
    audio.addListener(() => state++);
    audio.progressListenable.addListener(() => progress++);

    audio.setPositionForTesting(const Duration(seconds: 1));
    audio.setPositionForTesting(const Duration(seconds: 2));
    audio.setPositionForTesting(const Duration(seconds: 2)); // unchanged

    expect(progress, 2);
    expect(state, 0);
    expect(audio.position, const Duration(seconds: 2));
  });

  testWidgets('AudioProgressSelector rebuilds only when its value changes', (tester) async {
    final audio = AudioProvider();
    var builds = 0;
    await tester.pumpWidget(TestScope(
      overrides: [audioProvider.overrideWith((ref) => audio, disposeNotifier: false)],
      child: MaterialApp(
        home: AudioProgressSelector<int>(
          selector: (a) => a.position.inSeconds,
          builder: (context, seconds) {
            builds++;
            return Text('$seconds');
          },
        ),
      ),
    ));
    expect(find.text('0'), findsOneWidget);

    audio.setPositionForTesting(const Duration(milliseconds: 5400));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
    final afterFive = builds;

    // Same whole second: no rebuild.
    audio.setPositionForTesting(const Duration(milliseconds: 5800));
    await tester.pump();
    expect(builds, afterFive);

    audio.setPositionForTesting(const Duration(milliseconds: 6100));
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
  });
}
