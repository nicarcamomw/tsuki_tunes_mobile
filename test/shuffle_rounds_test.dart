import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

// Shuffle plays every song once before any repeats, however long the list,
// and keeps going the same way after the app is closed.

Track _t(int i, {int artists = 30}) => Track(
      id: 's$i',
      title: 'Song $i',
      artistId: 'a${i % artists}',
      artistName: 'Artist ${i % artists}',
      albumId: 'al${i % (artists * 2)}',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 180,
    );

bool _all(Track _) => true;

void main() {
  group('PlaybackQueue rounds', () {
    final songs = [for (var i = 0; i < 120; i++) _t(i)];

    PlaybackQueue shuffled(int seed) {
      final q = PlaybackQueue(random: Random(seed))..toggleShuffle();
      q.select(songs.first, newQueue: songs);
      return q;
    }

    test('a 120-song list: every song once before any plays again', () {
      for (final seed in [1, 2, 3]) {
        final q = shuffled(seed);
        final played = [q.current!.id];
        for (var k = 0; k < 119; k++) {
          q.next(online: true, canPlay: _all);
          played.add(q.current!.id);
        }
        expect(played.toSet().length, 120, reason: 'seed $seed: no song twice in a round');
      }
    });

    test('with repeat off it ends once every song was heard, not before', () {
      final q = shuffled(4);
      for (var k = 0; k < 118; k++) {
        expect(q.shouldStopAtEnd(), isFalse);
        q.next(online: true, canPlay: _all);
      }
      expect(q.shouldStopAtEnd(), isFalse);
      q.next(online: true, canPlay: _all);
      expect(q.shouldStopAtEnd(), isTrue);
    });

    test('the next round doesn\'t open with the songs that just played', () {
      final q = shuffled(5)..setRepeatMode(PlaybackRepeatMode.all);
      final round = [q.current!.id];
      for (var k = 0; k < 119; k++) {
        q.next(online: true, canPlay: _all);
        round.add(q.current!.id);
      }
      final lastOnes = round.sublist(round.length - 20).toSet();
      q.next(online: true, canPlay: _all);
      expect(lastOnes.contains(q.current!.id), isFalse);
      // And the second round goes through everything again too.
      final second = [q.current!.id];
      for (var k = 0; k < 119; k++) {
        q.next(online: true, canPlay: _all);
        second.add(q.current!.id);
      }
      expect(second.toSet().length, 120);
    });

    test('the songs heard survive a reorder of the queue', () {
      final q = shuffled(6);
      final played = {q.current!.id};
      for (var k = 0; k < 60; k++) {
        q.next(online: true, canPlay: _all);
        played.add(q.current!.id);
      }
      q.reorder(100, 5);
      for (var k = 0; k < 59; k++) {
        q.next(online: true, canPlay: _all);
        expect(played.add(q.current!.id), isTrue, reason: 'no repeat after the reorder');
      }
    });

    test('never the same artist twice in a row while others are left', () {
      final q = shuffled(7);
      var prev = q.current!.artistId;
      for (var k = 0; k < 119; k++) {
        q.next(online: true, canPlay: _all);
        final now = q.current!.artistId;
        expect(now, isNot(prev));
        prev = now;
      }
    });
  });

  group('Spread by share', () {
    Track song(int i, String artist, String album) => Track(
        id: 'k$i', title: 'S$i', artistId: artist, artistName: artist, albumId: album,
        albumTitle: album, coverUrl: '', previewUrl: '', durationSeconds: 180);
    // Half the songs by one artist (in 6 albums), the rest by 30 others.
    final skewed = [
      for (var i = 0; i < 60; i++) song(i, 'BIG', 'big${i % 6}'),
      for (var i = 60; i < 120; i++) song(i, 'a${i % 30}', 'al${i % 30}'),
    ];

    List<Track> round(List<Track> list, int seed) {
      final q = PlaybackQueue(random: Random(seed))..toggleShuffle();
      q.select(list[seed % list.length], newQueue: list);
      final order = [q.current!];
      for (var k = 1; k < list.length; k++) {
        q.next(online: true, canPlay: _all);
        order.add(q.current!);
      }
      return order;
    }

    test('a big artist is spread all round long, not piled up at the end', () {
      var pairs = 0, longest = 0, bigEarly = 0;
      for (var seed = 0; seed < 30; seed++) {
        final order = round(skewed, seed);
        var run = 1;
        for (var k = 1; k < order.length; k++) {
          if (order[k].artistId == order[k - 1].artistId) {
            pairs++;
            run++;
          } else {
            run = 1;
          }
          longest = max(longest, run);
        }
        bigEarly += order.take(60).where((t) => t.artistId == 'BIG').length;
      }
      // Before: about 47 same-artist pairs a round, runs of up to 49, and
      // only 9 of the big artist's 60 songs in the first half.
      expect(pairs / 30, lessThan(3));
      expect(longest, lessThanOrEqualTo(2));
      expect(bigEarly / 30, inInclusiveRange(26, 34));
    });

    test('a two-song artist\'s songs are spaced, not one after the other', () {
      final gaps = <int>[];
      for (var seed = 0; seed < 30; seed++) {
        final order = round(skewed, seed);
        for (var a = 0; a < 30; a++) {
          final at = [for (var k = 0; k < order.length; k++) if (order[k].artistId == 'a$a') k];
          expect(at.length, 2);
          gaps.add(at[1] - at[0]);
        }
      }
      // Before: as close as 2 songs apart at the end of a round.
      expect(gaps.reduce(min), greaterThanOrEqualTo(15));
      expect(gaps.reduce((a, b) => a + b) / gaps.length, greaterThan(35));
    });

    test('still chance: any song can open or close a round', () {
      final even = [for (var i = 0; i < 40; i++) song(i, 'x${i % 10}', 'y${i % 20}')];
      final firsts = <String>{}, lasts = <String>{};
      var sum = 0;
      for (var seed = 0; seed < 200; seed++) {
        final q = PlaybackQueue(random: Random(seed))..toggleShuffle();
        q.select(even.first, newQueue: even);
        final order = [q.current!];
        for (var k = 1; k < even.length; k++) {
          q.next(online: true, canPlay: _all);
          order.add(q.current!);
        }
        firsts.add(order[1].id);
        lasts.add(order.last.id);
        sum += order.indexWhere((t) => t.id == 'k7');
      }
      expect(firsts.length, greaterThan(25));
      expect(lasts.length, greaterThan(25));
      // On average a given song lands mid-round.
      expect(sum / 200, inInclusiveRange(14, 26));
    });
  });

  group('AudioProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
      messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
        if (call.method == 'init') {
          messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.methods.${(call.arguments as Map)['id']}'), (_) async => {});
        }
        return {};
      });
    });
    TestWidgetsFlutterBinding.ensureInitialized();

    final songs = [for (var i = 0; i < 40; i++) _t(i, artists: 10)];

    test('the shuffle button\'s "Aleatorio" turns shuffle on and starts anywhere', () async {
      final audio = AudioProvider(storage: StorageService());
      addTearDown(audio.dispose);
      await audio.playShuffled(songs[17], songs);
      expect(audio.shuffleMode, ShuffleMode.on);
      expect(audio.currentTrack?.id, 's17');
      expect(audio.queue.length, 40);
    });

    test('shuffle, repeat and the songs heard come back after the app closes', () async {
      final storage = StorageService();
      final audio = AudioProvider(storage: storage);
      await audio.playShuffled(songs.first, songs);
      audio.setRepeatMode(PlaybackRepeatMode.all);
      final heard = {audio.currentTrack!.id};
      for (var k = 0; k < 15; k++) {
        await audio.next();
        heard.add(audio.currentTrack!.id);
      }
      audio.persistPlaybackStateNowForTesting();
      await pumpEventQueue();
      final current = audio.currentTrack!.id;
      audio.dispose();

      // Android closed the app; it opens again.
      final again = AudioProvider(storage: storage);
      addTearDown(again.dispose);
      await again.restorePlaybackStateForTesting();
      expect(again.currentTrack?.id, current);
      expect(again.shuffleMode, ShuffleMode.on);
      expect(again.repeatMode, PlaybackRepeatMode.all);
      for (var k = 0; k < 24; k++) {
        await again.next();
        expect(heard.add(again.currentTrack!.id), isTrue, reason: 'no song of this round again');
      }
    });
  });
}
