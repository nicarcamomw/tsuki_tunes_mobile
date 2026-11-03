import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/system_volume.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_sleep_timer.dart';

class _Volume implements SystemVolumeSource {
  int current = 10;
  final sets = <int>[];

  @override
  Future<({int current, int max})?> read() async => (current: current, max: 15);

  @override
  Future<void> set(int index) async {
    sets.add(index);
    current = index;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioPlayerService service;
  late _Volume volume;
  late bool spotify;
  late bool playing;
  late int stops;

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async {
      if (call.method == 'init') {
        final id = call.arguments['id'];
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'), (call) async => {});
      }
      return {};
    });
    service = AudioPlayerService();
    volume = _Volume();
    spotify = false;
    playing = true;
    stops = 0;
    SleepTimerController.restoreDelay = const Duration(milliseconds: 20);
  });

  SleepTimerController timer() => SleepTimerController(
        service: service,
        onStateChanged: () {},
        onStop: () {
          stops++;
          playing = false;
        },
        fullSongPlaying: () => spotify,
        isPlaying: () => playing,
        systemVolume: volume,
      );

  /// Puts the timer [left] before its end and lets the fade take a step.
  Future<void> at(SleepTimerController t, Duration left) async {
    t.setDeadlineForTesting(DateTime.now().add(left));
    t.check();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (t.isFading) await t.fadeStep();
  }

  test('the fade lasts a minute, or the last third of a short timer', () {
    expect(SleepTimerController.fadeFor(const Duration(minutes: 30)), const Duration(seconds: 60));
    expect(SleepTimerController.fadeFor(const Duration(seconds: 90)), const Duration(seconds: 30));
  });

  test('previews fade on an even-sounding curve, then the volume comes back', () async {
    final t = timer()..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 90));
    expect(service.masterVolume, 1.0, reason: 'not yet');

    await at(t, const Duration(seconds: 30));
    expect(t.isFading, isTrue);
    expect(service.masterVolume, closeTo(0.25, 0.03), reason: 'half way: (1/2)²');

    await at(t, const Duration(milliseconds: -1));
    expect(stops, 1);
    expect(t.isFading, isFalse);
    expect(service.masterVolume, 1.0, reason: 'the next play is not silent');
    expect(volume.sets, isEmpty, reason: 'the phone\'s volume untouched');
    t.dispose();
  });

  test('with Spotify the phone\'s volume fades and is put back after the pause', () async {
    spotify = true;
    final t = timer()..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 30));
    expect(volume.sets.last, 5, reason: 'half of 10');

    await at(t, const Duration(seconds: 6));
    expect(volume.sets.last, 1);

    await at(t, const Duration(milliseconds: -1));
    expect(stops, 1);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(volume.current, 10, reason: 'as it was before the fade');
    t.dispose();
  });

  test('a volume moved by hand during the fade is left alone', () async {
    spotify = true;
    final t = timer()..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 30));
    expect(volume.sets.last, 5);

    volume.current = 8; // the user turned it up
    await at(t, const Duration(seconds: 10));
    expect(volume.sets.last, 5, reason: 'no more changes');

    await at(t, const Duration(milliseconds: -1));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(volume.current, 8, reason: 'theirs, not put back');
    t.dispose();
  });

  test('still playing after the stop: volume stays down until the next play', () async {
    spotify = true;
    final t = SleepTimerController(
      service: service,
      onStateChanged: () {},
      onStop: () => stops++, // Spotify didn't pause
      fullSongPlaying: () => spotify,
      isPlaying: () => playing,
      systemVolume: volume,
    )..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 30));
    await at(t, const Duration(milliseconds: -1));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(volume.current, isNot(10), reason: 'not blasting someone asleep');

    await t.restoreVolume();
    expect(volume.current, 10);
    t.dispose();
  });

  test('cancelling during the fade brings both volumes back at once', () async {
    spotify = true;
    final t = timer()..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 30));
    expect(volume.current, 5);

    t.set(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(volume.current, 10);
    expect(service.masterVolume, 1.0);
    expect(t.isFading, isFalse);
    expect(stops, 0);
    t.dispose();
  });

  test('paused when the fade would start: nothing to fade', () async {
    playing = false;
    final t = timer()..set(const Duration(minutes: 30));
    await at(t, const Duration(seconds: 30));
    expect(t.isFading, isFalse);
    t.dispose();
  });
}
