import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';

// just_audio 0.10 reports playback errors (a stream that drops mid-song) on
// errorStream instead of as errors of playbackEventStream. AudioProvider
// listens for them on the service's playbackEventStream, so the service
// passes them on there: without it they'd be silently lost.

class _Player implements AudioPlayer {
  // ignore: close_sinks (lives as long as the test)
  final errors = StreamController<PlayerException>.broadcast();

  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<SequenceState> get sequenceStateStream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('an error of the playing deck reaches playbackEventStream, as before 0.10', () async {
    final a = _Player();
    final service = AudioPlayerService.withPlayers(a, _Player());
    final heard = <Object>[];
    service.playbackEventStream.listen((_) {}, onError: heard.add);

    a.errors.add(PlayerException(0, 'Source error', null));
    await Future<void>.delayed(Duration.zero);

    expect(heard.single, isA<PlayerException>());
    expect((heard.single as PlayerException).message, 'Source error');
  });

  test('the standby deck\'s errors are not the playing song\'s', () async {
    final b = _Player();
    final service = AudioPlayerService.withPlayers(_Player(), b);
    final heard = <Object>[];
    service.playbackEventStream.listen((_) {}, onError: heard.add);

    b.errors.add(PlayerException(0, 'standby', null));
    await Future<void>.delayed(Duration.zero);

    expect(heard, isEmpty);
  });
}
