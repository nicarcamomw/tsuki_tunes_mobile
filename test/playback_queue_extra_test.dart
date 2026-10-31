import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/repeat_mode.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';

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

  group('restore', () {
    test('sets queue and index without clearing history', () {
      q.next(online: true, canPlay: _all);
      q.restore(tracks, 3);
      expect(q.currentIndex, 3);
      expect(q.current!.id, 't3');
      expect(q.history, isNotEmpty);
    });

    test('clamps invalid index to 0', () {
      q.restore(tracks, 99);
      expect(q.currentIndex, 0);
    });

    test('handles empty list', () {
      q.restore([], 0);
      expect(q.currentIndex, -1);
      expect(q.isEmpty, isTrue);
    });
  });

  group('append', () {
    test('adds new tracks and returns count', () {
      final extra = [_t('x1'), _t('x2')];
      expect(q.append(extra), 2);
      expect(q.length, 7);
    });

    test('skips duplicates', () {
      expect(q.append([_t('t0'), _t('t1'), _t('x')]), 1);
      expect(q.length, 6);
    });

    test('returns 0 when all are duplicates', () {
      expect(q.append([_t('t0')]), 0);
      expect(q.length, 5);
    });
  });

  group('replaceUpcoming', () {
    test('reorders tail when ids match', () {
      q.select(tracks[0]);
      final reordered = [tracks[4], tracks[3], tracks[2], tracks[1]];
      q.replaceUpcoming(reordered);
      expect(q.tracks.skip(1).map((t) => t.id), ['t4', 't3', 't2', 't1']);
    });

    test('rejects when ids do not match', () {
      q.select(tracks[0]);
      q.replaceUpcoming([_t('x'), tracks[2], tracks[3], tracks[4]]);
      expect(q.tracks[1].id, 't1');
    });
  });

  group('dropBefore', () {
    test('removes tracks before current and adjusts index', () {
      q.select(tracks[3]);
      q.dropBefore(2);
      expect(q.currentIndex, 1);
      expect(q.tracks.first.id, 't2');
      expect(q.length, 3);
    });

    test('does nothing when count is 0 or exceeds currentIndex', () {
      q.select(tracks[2]);
      q.dropBefore(0);
      expect(q.length, 5);
      q.dropBefore(3);
      expect(q.length, 5);
    });
  });

  group('replaceTrack', () {
    test('updates track with matching id', () {
      final updated = _t('t2', artist: 'new_artist');
      q.replaceTrack(updated);
      expect(q.tracks[2].artistId, 'new_artist');
    });
  });

  group('repeat modes', () {
    test('cycleRepeatMode goes off -> all -> one -> off', () {
      expect(q.repeatMode, PlaybackRepeatMode.off);
      expect(q.cycleRepeatMode(), PlaybackRepeatMode.all);
      expect(q.cycleRepeatMode(), PlaybackRepeatMode.one);
      expect(q.cycleRepeatMode(), PlaybackRepeatMode.off);
    });

    test('repeat one with next still advances to next track', () {
      q.setRepeatMode(PlaybackRepeatMode.one);
      final peeked = q.peekNext();
      expect(peeked, 1);
    });
  });

  group('crossfade', () {
    test('advanceForCrossfade works with shuffle', () {
      q.toggleShuffle();
      final target = q.advanceForCrossfade();
      expect(target, isNotNull);
      expect(target, isNot(0));
      expect(q.history, [0]);
    });
  });

  group('offline previous', () {
    test('offline previous skips uncached tracks', () {
      q.select(tracks[3]);
      final step = q.previous(
        position: Duration.zero,
        online: false,
        canPlay: (t) => t.id == 't1',
      );
      expect(step.kind, QueueStepKind.play);
      expect(step.index, 1);
    });
  });
}
