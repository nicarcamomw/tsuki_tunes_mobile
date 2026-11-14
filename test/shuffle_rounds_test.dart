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
