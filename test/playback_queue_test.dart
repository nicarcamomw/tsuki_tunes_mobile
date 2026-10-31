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

  test('smart shuffle never plays the same artist twice in a row', () {
    final mixed = [
      _t('x0', artist: 'x'),
      _t('x1', artist: 'x'),
      _t('y0', artist: 'y'),
    ];
    for (var seed = 0; seed < 50; seed++) {
      final sq = PlaybackQueue(random: Random(seed));
      sq.select(mixed[0], newQueue: mixed);
      sq.toggleShuffle();
      sq.next(online: true, canPlay: _all);
      // Just heard artist 'x' (x0): y0 comes before x1.
      expect(sq.current!.id, 'y0');
    }
  });

  test('with it off, the same artist may follow', () {
    final mixed = [
      _t('x0', artist: 'x'),
      _t('x1', artist: 'x'),
      _t('y0', artist: 'y'),
    ];
    final next = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      final sq = PlaybackQueue(random: Random(seed))..avoidSameArtist = false;
      sq.select(mixed[0], newQueue: mixed);
      sq.toggleShuffle();
      sq.next(online: true, canPlay: _all);
      next.add(sq.current!.id);
    }
    expect(next, containsAll(['x1', 'y0']));
  });

  group('editing', () {
    test('insertNext places after current and shifts history', () {
      q.select(tracks[2]);
      q.next(online: true, canPlay: _all); // history [2], current 3
      expect(q.insertNext(_t('n')), isTrue);
      expect(q.tracks[4].id, 'n');
      // Again: stays next, never duplicated. The current track can't be.
      expect(q.insertNext(_t('n')), isTrue);
      expect(q.tracks.where((t) => t.id == 'n'), hasLength(1));
      expect(q.tracks[4].id, 'n');
      expect(q.insertNext(q.current!), isFalse);
      expect(q.history, [2]);
    });

    group('peekUpcoming', () {
      test('list order, stopping at the end or wrapping with repeat-all', () {
        q.select(tracks[3]);
        expect(q.peekUpcoming(5), [4]);
        q.setRepeatMode(PlaybackRepeatMode.all);
        expect(q.peekUpcoming(3), [4, 0, 1]);
        q.setRepeatMode(PlaybackRepeatMode.one);
        expect(q.peekUpcoming(3), isEmpty);
      });

      test('shuffle picks ahead are the ones next() then plays', () {
        q.toggleShuffle();
        final ahead = q.peekUpcoming(3);
        expect(ahead.toSet(), hasLength(3));
        expect(ahead, isNot(contains(q.currentIndex)));
        for (final i in ahead) {
          q.next(online: true, canPlay: _all);
          expect(q.currentIndex, i);
        }
      });

      test('selecting the track next() moved to keeps the picks ahead', () {
        q.toggleShuffle();
        final ahead = q.peekUpcoming(3);
        for (final i in ahead) {
          q.next(online: true, canPlay: _all);
          // The player then plays it, selecting it again.
          q.select(q.tracks[q.currentIndex]);
          expect(q.currentIndex, i);
        }
      });

      test('picking another song in the queue redoes the picks', () {
        q.toggleShuffle();
        final ahead = q.peekUpcoming(3);
        final other = [for (var i = 0; i < q.length; i++) i]
            .firstWhere((i) => i != q.currentIndex && i != ahead.first);
        q.select(q.tracks[other]);
        expect(q.nextShuffleIndex, isNull);
      });

      test('queueing by hand redoes the picks with the queued song first', () {
        q.toggleShuffle();
        q.peekUpcoming(3);
        q.enqueue([_t('q1')]);
        expect(q.tracks[q.peekUpcoming(3).first].id, 'q1');
      });
    });

    group('user queue', () {
      List<String> ids() => q.tracks.map((t) => t.id).toList();
      String step() {
        q.next(online: true, canPlay: _all);
        return q.current!.id;
      }

      test('queued songs go after the current one, in order, before the album',
          () {
        q.enqueue([_t('q1')]);
        q.enqueue([_t('q2')]);
        expect(ids(), ['t0', 'q1', 'q2', 't1', 't2', 't3', 't4']);
        expect(q.userQueue, ['q1', 'q2']);
        expect(step(), 'q1');
        expect(q.isUserQueued('q1'), isFalse);
        expect(step(), 'q2');
        expect(step(), 't1');
        expect(q.userQueue, isEmpty);
      });

      test('queueing a song already later in the album moves it up', () {
        expect(q.enqueue([tracks[4]]), 1);
        expect(ids(), ['t0', 't4', 't1', 't2', 't3']);
        expect(q.enqueue([q.current!]), 0);
      });

      test('play next goes ahead of what was queued', () {
        q.enqueue([_t('q1')]);
        q.insertNext(_t('n'));
        expect(ids().take(3), ['t0', 'n', 'q1']);
        expect(q.userQueue, ['n', 'q1']);
      });

      test('app-picked tracks are not marked as queued by hand', () {
        q.insertNext(_t('run'), userQueued: false);
        expect(q.isUserQueued('run'), isFalse);
        q.enqueue([_t('q1')]);
        expect(ids().take(3), ['t0', 'q1', 'run']);
      });

      test('queued songs win over shuffle picks', () {
        q.toggleShuffle();
        q.peekNext(); // memoizes a random pick
        q.enqueue([_t('q1'), _t('q2')]);
        expect(q.tracks[q.peekNext()!].id, 'q1');
        expect(step(), 'q1');
        expect(step(), 'q2');
      });

      test('queued songs stay up next when a new album starts', () {
        q.enqueue([_t('q1')]);
        final album = [for (var i = 0; i < 3; i++) _t('b$i')];
        q.select(album[1], newQueue: album);
        expect(ids(), ['b0', 'b1', 'q1', 'b2']);
        expect(step(), 'q1');
      });

      test('jumping to another song keeps the queue right after it', () {
        q.enqueue([_t('q1')]);
        q.select(tracks[3]);
        expect(q.current!.id, 't3');
        expect(step(), 'q1');
        expect(step(), 't4');
      });

      test('removing or clearing drops songs from the user queue', () {
        q.enqueue([_t('q1'), _t('q2')]);
        q.removeAt(1);
        expect(q.userQueue, ['q2']);
        q.clear(keep: q.current);
        expect(q.userQueue, isEmpty);
      });

      test('dragging a queued song down into the list unqueues it', () {
        q.enqueue([_t('q1'), _t('q2')]);
        q.reorder(1, 5); // q1 after t2
        expect(q.userQueue, ['q2']);
      });
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
