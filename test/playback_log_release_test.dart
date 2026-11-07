import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/logger.dart';
import 'package:tsuki_tunes_mobile/data/datasources/media_session_handler.dart';
import 'package:tsuki_tunes_mobile/data/datasources/playback_log.dart';

void main() {
  late DebugPrintCallback original;
  late List<String> system;

  setUp(() {
    PlaybackLog.instance.clear();
    original = debugPrint;
    system = [];
    // As main wires it in a release build: the playback log keeps it, the
    // system log never sees it.
    debugPrint = (String? message, {int? wrapWidth}) {
      PlaybackLog.instance.capture(message);
    };
    Log.init(release: true);
  });

  tearDown(() {
    debugPrint = original;
    Log.init(release: false);
  });

  test('in a release build, what playback decided reaches the log the user copies', () async {
    Log.named('AudioProvider').info('Spotify skipped ahead (its own "next"), doing ours');
    Log.named('AudioProvider').fine('position sync'); // too chatty for release
    Log.named('Masks').info('cloud sync'); // not playback
    await pumpEventQueue();

    final lines = PlaybackLog.instance.dump().split('\n');
    expect(lines, hasLength(1));
    expect(lines.single, contains('[AudioProvider] Spotify skipped ahead'));
    expect(system, isEmpty);
  });

  test("the car's buttons are in the log, and still do their job", () async {
    var nexts = 0, previous = 0;
    final handler = TsukiAudioHandler()
      ..onSkipToNext = (() async => nexts++)
      ..onSkipToPrevious = (() async => previous++);

    await handler.skipToNext();
    await handler.skipToPrevious();
    await pumpEventQueue();

    expect((nexts, previous), (1, 1));
    final log = PlaybackLog.instance.dump();
    expect(log, contains('[MediaSession] system: next'));
    expect(log, contains('[MediaSession] system: previous'));
  });
}
