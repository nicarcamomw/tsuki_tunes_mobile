import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') {
          final id = methodCall.arguments['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            (MethodCall call) async => {},
          );
        }
        return {};
      },
    );
  });

  test('fires once per play after 80% when enabled', () async {
    final provider = AudioProvider();
    final marked = <String>[];
    provider.onListenedThreshold = (t) => marked.add(t.id);
    await provider.setAutoMarkListened(true);

    final track = _track('1');
    await provider.playTrack(track, newQueue: [track]);

    provider.setPositionForTesting(const Duration(seconds: 70));
    provider.checkListenedThresholdForTesting();
    expect(marked, isEmpty);

    provider.setPositionForTesting(const Duration(seconds: 81));
    provider.checkListenedThresholdForTesting();
    provider.checkListenedThresholdForTesting();
    expect(marked, ['1']);
  });

  test('does nothing when disabled', () async {
    final provider = AudioProvider();
    final marked = <String>[];
    provider.onListenedThreshold = (t) => marked.add(t.id);
    await provider.setAutoMarkListened(false);

    final track = _track('1');
    await provider.playTrack(track, newQueue: [track]);
    provider.setPositionForTesting(const Duration(seconds: 95));
    provider.checkListenedThresholdForTesting();
    expect(marked, isEmpty);
  });
}
