import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/playback_log.dart';

void main() {
  setUp(PlaybackLog.instance.clear);

  test('keeps playback events with their time, and nothing else', () {
    final log = PlaybackLog.instance;
    log.capture('[AudioProvider] Spotify app stopped answering, reconnecting');
    log.capture('Spotify: found URI=spotify:track:1');
    log.capture('[Masks] cloud sync error');
    log.capture(null);
    final lines = log.dump().split('\n');
    expect(lines, hasLength(2));
    expect(lines.first, matches(RegExp(r'^\d\d:\d\d:\d\d\.\d\d \[AudioProvider\] Spotify app')));
  });

  test('holds only the latest events', () {
    final log = PlaybackLog.instance;
    for (var i = 0; i < PlaybackLog.maxLines + 50; i++) {
      log.capture('[AudioProvider] event $i');
    }
    expect(log.length, PlaybackLog.maxLines);
    expect(log.dump(), contains('event ${PlaybackLog.maxLines + 49}'));
    expect(log.dump(), isNot(contains('event 0\n')));
  });
}
