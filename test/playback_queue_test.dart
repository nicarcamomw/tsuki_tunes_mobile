import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/repeat_mode.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/services/playback_queue.dart';

Track _t(String id, {String artist = 'a', String album = 'al'}) => Track(
      id: id,
      title: id,
      artistId: artist,
      artistName: artist,
      albumId: album,
      albumTitle: album,
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 30,
    );

bool _all(Track _) => true;

void main() {
  late List<Track> tracks;
  late PlaybackQueue q;

  setUp(() {
    tracks = [for (var i = 0; i < 5; i++) _t('t$i', artist: 'a$i')];
    q = PlaybackQueue(random: Random(1));
    q.select(tracks[0], newQueue: tracks);
  });

  test('select replaces the queue or selects/appends in place', () {
    expect(q.currentIndex, 0);
    q.select(tracks[3]);
    expect(q.currentIndex, 3);
    final extra = _t('x');
    q.select(extra);
    expect(q.length, 6);
    expect(q.current, extra);

    q.select(_t('missing'), newQueue: tracks);
    expect(q.tracks.first.id, 'missing');
    expect(q.currentIndex, 0);
  });

  group('next', () {
    test('linear order wraps online and records history', () {
      q.select(tracks[4]);
      final step = q.next(online: true, canPlay: _all);
      expect(step.kind, QueueStepKind.play);
      expect(step.index, 0);
      expect(q.history, [4]);
    });

    test('offline skips uncached tracks', () {
      final step = q.next(online: false, canPlay: (t) => t.id == 't3');
      expect(step.index, 3);
    });

    test('offline with nothing cached is unavailable', () {
      final step = q.next(online: false, canPlay: (_) => false);
      expect(step.kind, QueueStepKind.unavailable);
      expect(q.currentIndex, 0);
    });

    test('shuffle uses the memoized peek', () {
      q.toggleShuffle();
      final peeked = q.peekNext();
      final step = q.next(online: true, canPlay: _all);
      expect(step.index, peeked);
      expect(q.nextShuffleIndex, isNull);
    });
  });

  group('previous', () {
    test('restarts the track after 3 seconds', () {
      q.select(tracks[2]);
      final step = q.previous(
          position: const Duration(seconds: 10), online: true, canPlay: _all);
      expect(step.kind, QueueStepKind.seekToStart);
    });

    test('first track restarts when repeat is off, wraps with repeat all', () {
      expect(
          q.previous(position: Duration.zero, online: true, canPlay: _all).kind,
          QueueStepKind.seekToStart);
      q.setRepeatMode(PlaybackRepeatMode.all);
      final step =
          q.previous(position: Duration.zero, online: true, canPlay: _all);
      expect(step.index, 4);
    });

    test('shuffle walks back through history', () {
      q.toggleShuffle();
      final first = q.currentIndex;
      q.next(online: true, canPlay: _all);
      final second = q.currentIndex;
      q.next(online: true, canPlay: _all);
      expect(
          q.previous(position: Duration.zero, online: true, canPlay: _all)
              .index,
          second);
      expect(
          q.previous(position: Duration.zero, online: true, canPlay: _all)
              .index,
          first);
      expect(
          q.previous(position: Duration.zero, online: true, canPlay: _all)
              .kind,
          QueueStepKind.seekToStart);
    });
  });

  test('peekNext honours repeat modes at the end of the queue', () {
    q.select(tracks[4]);
    expect(q.peekNext(), isNull);
    q.setRepeatMode(PlaybackRepeatMode.all);
    expect(q.peekNext(), 0);
    q.setRepeatMode(PlaybackRepeatMode.one);
    expect(q.peekNext(), 4);
  });

  test('shouldStopAtEnd only at the last track (linear)', () {
    expect(q.shouldStopAtEnd(), isFalse);
    q.select(tracks[4]);
    expect(q.shouldStopAtEnd(), isTrue);
  });

  test('smart shuffle avoids the artist just played', () {
    final mixed = [
      _t('x0', artist: 'x'),
      _t('x1', artist: 'x'),
      _t('y0', artist: 'y'),
    ];
    var checked = 0;
    for (var seed = 0; seed < 50; seed++) {
      final sq = PlaybackQueue(random: Random(seed));
      sq.select(mixed[0], newQueue: mixed);
      sq.toggleShuffle();
      sq.next(online: true, canPlay: _all);
      // Just heard artist 'x' (x1): the -3 penalty must rule out x0.
      if (sq.current!.id != 'x1') continue;
      checked++;
      sq.next(online: true, canPlay: _all);
      expect(sq.current!.id, 'y0');
    }
    expect(checked, greaterThan(0));
  });

  group('editing', () {
    test('insertNext places after current and shifts history', () {
      q.select(tracks[2]);
      q.next(online: true, canPlay: _all); // history [2], current 3
      expect(q.insertNext(_t('n')), isTrue);
      expect(q.tracks[4].id, 'n');
      expect(q.insertNext(_t('n')), isFalse);
      expect(q.history, [2]);
    });

    test('removeAt keeps the current track selected', () {
      q.select(tracks[3]);
      expect(q.removeAt(1), isFalse);
      expect(q.current!.id, 't3');
      expect(q.removeAt(q.currentIndex), isTrue);
      expect(q.current!.id, 't4');
    });

    test('reorder keeps the current track and clears history', () {
      q.select(tracks[1]);
      q.next(online: true, canPlay: _all);
      q.reorder(0, 4);
      expect(q.current!.id, 't2');
      expect(q.history, isEmpty);
    });

    test('clear keeps only the playing track', () {
      q.clear(keep: tracks[2]);
      expect(q.tracks.map((t) => t.id), ['t2']);
      expect(q.currentIndex, 0);
    });
  });

  test('advanceForCrossfade stops at the end unless repeating', () {
    q.select(tracks[4]);
    expect(q.advanceForCrossfade(), isNull);
    q.setRepeatMode(PlaybackRepeatMode.all);
    expect(q.advanceForCrossfade(), 0);
    expect(q.history, [4]);
  });
}
