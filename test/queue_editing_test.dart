import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';

Track _t(String id, {String? artist}) => Track(
      id: id,
      title: id,
      artistId: artist ?? 'a_$id',
      artistName: artist ?? 'a_$id',
      albumId: 'al_$id',
      albumTitle: 'al_$id',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 30,
    );

bool _all(Track _) => true;

void main() {
  late List<Track> tracks;
  late PlaybackQueue q;

  List<String> ids(List<int> idx) => [for (final i in idx) q.tracks[i].id];

  setUp(() {
    tracks = [for (var i = 0; i < 8; i++) _t('t$i')];
    q = PlaybackQueue(random: Random(3));
    q.select(tracks[0], newQueue: tracks);
  });

  group('upcoming and played', () {
    test('in list order: what follows and what came before', () {
      q.select(tracks[3]);
      expect(ids(q.upcoming(3)), ['t4', 't5', 't6']);
      expect(q.upcomingCount, 4);
      expect(ids(q.played()), ['t0', 't1', 't2']);
    });

    test('shuffle lists the songs next() will play, in order', () {
      q.toggleShuffle();
      final shown = ids(q.upcoming(5));
      final played = <String>[];
      for (var i = 0; i < 5; i++) {
        q.next(online: true, canPlay: _all);
        played.add(q.current!.id);
      }
      expect(played, shown);
      expect(q.played().length, 5);
    });

    test('shuffle plays every song once before repeating one', () {
      q.toggleShuffle();
      final heard = {q.current!.id};
      for (var i = 0; i < tracks.length - 1; i++) {
        q.next(online: true, canPlay: _all);
        heard.add(q.current!.id);
      }
      expect(heard.length, tracks.length);
    });
  });

  group('shuffle order stays put while editing', () {
    test('adding to the queue keeps the order made ahead', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(5));
      q.enqueue([_t('x')]);
      expect(ids(q.upcoming(6)), ['x', ...before]);
    });

    test('play next goes first, ahead of what you queued', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(4));
      q.enqueue([_t('x')]);
      q.insertNext(_t('y'));
      expect(ids(q.upcoming(6)), ['y', 'x', ...before]);
    });

    test('removing a song keeps the others in place', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(5));
      final gone = q.tracks.indexWhere((t) => t.id == before[2]);
      q.removeAt(gone);
      expect(ids(q.upcoming(4)), [...before]..removeAt(2));
    });

    test('picking an upcoming song keeps the ones after it', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(5));
      q.select(q.tracks.firstWhere((t) => t.id == before[2]));
      expect(ids(q.upcoming(2)), before.sublist(3, 5));
    });
  });

  group('moveUpcoming', () {
    test('in list order it moves the song in the list', () {
      q.moveUpcoming(0, 2);
      expect(ids(q.upcoming(4)), ['t2', 't3', 't1', 't4']);
      expect(q.current!.id, 't0');
    });

    test('with shuffle it reorders what plays next', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(4));
      q.moveUpcoming(3, 0);
      final after = ids(q.upcoming(4));
      expect(after, [before[3], before[0], before[1], before[2]]);
      q.next(online: true, canPlay: _all);
      expect(q.current!.id, before[3]);
    });

    test('dropped inside your queue it joins it, past it it leaves it', () {
      q.enqueue([_t('x'), _t('y')]);
      expect(ids(q.upcoming(3)), ['x', 'y', 't1']);
      // t1 dropped between x and y: queued by you now.
      q.moveUpcoming(2, 1);
      expect(q.isUserQueued('t1'), isTrue);
      // y dragged far down: back to being part of the list.
      final yAt = ids(q.upcoming(8)).indexOf('y');
      q.moveUpcoming(yAt, 5);
      expect(q.isUserQueued('y'), isFalse);
      expect(q.userQueue, ['x', 't1']);
    });
  });

  group('snapshot', () {
    test('restores a removed song where it was, still queued by you', () {
      q.enqueue([_t('x')]);
      final snap = q.snapshot();
      q.removeAt(q.tracks.indexWhere((t) => t.id == 'x'));
      expect(q.restoreSnapshot(snap), isTrue);
      expect(ids(q.upcoming(2)), ['x', 't1']);
      expect(q.isUserQueued('x'), isTrue);
    });

    test('restores a cleared queue', () {
      final snap = q.snapshot();
      q.clear(keep: q.current);
      expect(q.restoreSnapshot(snap), isTrue);
      expect(q.length, tracks.length);
      expect(q.current!.id, 't0');
    });

    test('keeps the song playing now if it moved on meanwhile', () {
      final snap = q.snapshot();
      q.removeAt(3);
      q.next(online: true, canPlay: _all);
      expect(q.restoreSnapshot(snap), isTrue);
      expect(q.current!.id, 't1');
      expect(ids(q.upcoming(3)), ['t2', 't3', 't4']);
    });

    test('shuffle order comes back too', () {
      q.toggleShuffle();
      final before = ids(q.upcoming(5));
      final snap = q.snapshot();
      q.removeAt(q.tracks.indexWhere((t) => t.id == before[0]));
      q.restoreSnapshot(snap);
      expect(ids(q.upcoming(5)), before);
    });
  });
}
