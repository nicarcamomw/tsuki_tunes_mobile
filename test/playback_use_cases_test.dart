import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/playback_controller.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playback/add_to_queue.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_next.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_track.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/playback/play_tracks.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

/// A player that only remembers what it was asked to do.
class _FakePlayer implements PlaybackController {
  final queue = <Track>[];
  @override
  Track? currentTrack;
  @override
  bool isPlaying = false;

  @override
  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    if (newQueue != null) {
      queue
        ..clear()
        ..addAll(newQueue);
    }
    currentTrack = track;
    isPlaying = true;
  }

  @override
  Future<void> togglePlay() async => isPlaying = !isPlaying;

  @override
  void playNext(Track track, {bool userQueued = true}) {
    final at = currentTrack == null ? 0 : queue.indexOf(currentTrack!) + 1;
    queue.insert(at, track);
  }

  @override
  void addToQueue(Track track) => queue.add(track);

  @override
  void addAllToQueue(List<Track> tracks) => queue.addAll(tracks);

  @override
  void removeFromQueue(int index) => queue.removeAt(index);

  @override
  Future<bool> startRadio(Track seed) async => true;

  @override
  Future<bool> startArtistRadio(Artist artist) async => true;
}

void main() {
  late _FakePlayer player;
  setUp(() => player = _FakePlayer());

  final songs = [for (final id in ['1', '2', '3', '4', '5']) _t(id)];

  test('playing a list starts at its first song with the list as queue', () async {
    expect(await PlayTracks(player)(songs), isTrue);
    expect(player.currentTrack?.id, '1');
    expect(player.queue.map((t) => t.id), ['1', '2', '3', '4', '5']);
  });

  test('shuffling plays every song once, in a new order', () async {
    await PlayTracks(player, random: Random(7))(songs, shuffled: true);
    expect(player.queue.map((t) => t.id).toSet(), {'1', '2', '3', '4', '5'});
    expect(player.queue.map((t) => t.id), isNot(['1', '2', '3', '4', '5']));
    expect(player.currentTrack, player.queue.first);
    expect(songs.map((t) => t.id), ['1', '2', '3', '4', '5'], reason: 'the list is untouched');
  });

  test('an empty list plays nothing', () async {
    expect(await PlayTracks(player)([]), isFalse);
    expect(player.currentTrack, isNull);
  });

  test('a song from a list plays in its place, and the queue can grow', () async {
    await PlayTrack(player)(songs[2], queue: songs);
    expect(player.currentTrack?.id, '3');

    PlayNext(player)(_t('x'));
    AddToQueue(player)(_t('y'));
    expect(player.queue.map((t) => t.id), ['1', '2', '3', 'x', '4', '5', 'y']);
  });
}
