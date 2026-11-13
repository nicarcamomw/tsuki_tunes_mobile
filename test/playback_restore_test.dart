import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_restore.dart';

Map<String, dynamic> _song(String id, {int seconds = 200}) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Band',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://cdn/$id.mp3',
      durationSeconds: seconds,
    ).toJson();

final _now = DateTime(2026, 11, 12, 20);

Map<String, dynamic> _saved({
  int index = 1,
  int positionMs = 30000,
  bool wasPlaying = false,
  Duration ago = const Duration(minutes: 1),
  Map<String, dynamic>? radio,
}) =>
    {
      'queue': [_song('a'), _song('b'), _song('c')],
      'currentIndex': index,
      'position': positionMs,
      'wasPlaying': wasPlaying,
      'savedAt': _now.subtract(ago).millisecondsSinceEpoch,
      if (radio != null) 'radio': radio,
    };

void main() {
  test('comes back to the saved song and position, with the radio', () {
    final plan = planPlaybackRestore(_saved(radio: {'seed': 'x'}), _now)!;
    expect(plan.track.id, 'b');
    expect(plan.position, const Duration(seconds: 30));
    expect(plan.advanced, isFalse);
    expect(plan.radio, {'seed': 'x'});
    expect(plan.queue.map((t) => t.id), ['a', 'b', 'c']);
  });

  test('paused: the position is kept however long ago it was', () {
    final plan = planPlaybackRestore(_saved(ago: const Duration(days: 3)), _now)!;
    expect(plan.track.id, 'b');
    expect(plan.position, const Duration(seconds: 30));
  });

  test("killed while playing, the song still going: it's where it was saved", () {
    // 30 s in, saved 1 min ago, 200 s long: it hasn't ended.
    final plan = planPlaybackRestore(_saved(wasPlaying: true), _now)!;
    expect(plan.track.id, 'b');
    expect(plan.advanced, isFalse);
  });

  test('killed while playing, long enough for the song to end: the next one, from the start, no radio', () {
    final plan = planPlaybackRestore(
        _saved(wasPlaying: true, ago: const Duration(minutes: 5), radio: {'seed': 'x'}), _now)!;
    expect(plan.track.id, 'c');
    expect(plan.position, Duration.zero);
    expect(plan.advanced, isTrue);
    expect(plan.radio, isNull);
  });

  test('the last song ending goes round to the first', () {
    final plan = planPlaybackRestore(
        _saved(index: 2, wasPlaying: true, ago: const Duration(hours: 1)), _now)!;
    expect(plan.track.id, 'a');
  });

  test('a single song is never advanced', () {
    final state = _saved(wasPlaying: true, ago: const Duration(hours: 1))
      ..['queue'] = [_song('solo')]
      ..['currentIndex'] = 0;
    expect(planPlaybackRestore(state, _now)!.track.id, 'solo');
  });

  test('nothing usable: nothing to bring back', () {
    expect(planPlaybackRestore({}, _now), isNull);
    expect(planPlaybackRestore({'queue': []}, _now), isNull);
    expect(planPlaybackRestore({'queue': ['junk', 3]}, _now), isNull);
  });

  test('a bad index or position falls back to the first song, from the start', () {
    final state = _saved()
      ..['currentIndex'] = 99
      ..['position'] = 'soon';
    final plan = planPlaybackRestore(state, _now)!;
    expect(plan.track.id, 'a');
    expect(plan.position, Duration.zero);
  });
}
