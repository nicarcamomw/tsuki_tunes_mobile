import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/similar_track.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_queue.dart';
import 'package:tsuki_tunes_mobile/domain/logic/song_radio.dart';

Track _t(String id, String title, String artistId, String artist) => Track(
      id: id,
      title: title,
      artistId: artistId,
      artistName: artist,
      albumId: 'al$id',
      albumTitle: 'album',
      coverUrl: '',
      previewUrl: 'https://cdn/preview/$id.mp3',
      durationSeconds: 200,
    );

final _seed = _t('s', 'Toxicity', 'soad', 'System of a Down');

/// Deezer radio: 3 artists x 5 songs each.
Future<List<Track>> _deezerRadio(String artistId) async => [
      for (var a = 0; a < 3; a++)
        for (var s = 0; s < 5; s++) _t('dz$a-$s', 'Song $a-$s', 'art$a', 'Artist $a'),
    ];

Future<List<SimilarTrack>> _similar(String artist, String title) async => [
      const SimilarTrack('Deftones', 'Change (In the House of Flies)', 0.9),
      const SimilarTrack('Korn', 'Freak on a Leash', 0.8),
      const SimilarTrack('System of a Down', 'Toxicity', 0.7), // the seed
    ];

Future<List<Track>> _search(String query) async {
  if (query.contains('Deftones')) {
    return [
      _t('df-live', 'Change (In the House of Flies) - Live', 'deftones', 'Deftones'),
      _t('df', 'Change (In the House of Flies)', 'deftones', 'Deftones'),
    ];
  }
  if (query.contains('Korn')) {
    return [_t('kn', 'Freak On a Leash', 'korn', 'Korn')];
  }
  if (query.contains('Toxicity')) {
    return [_t('s-remaster', 'Toxicity (Remastered)', 'soad', 'System of a Down')];
  }
  return [];
}

SongRadio _radio({RadioMode mode = RadioMode.balanced}) => SongRadio(
      seed: _seed,
      mode: mode,
      similar: _similar,
      artistRadio: _deezerRadio,
      search: _search,
      useLastFm: true,
      random: Random(7),
    );

void main() {
  test('mixes both sources and explains each pick', () async {
    final radio = _radio();
    final batch = await radio.nextBatch(count: 8);

    expect(batch, isNotEmpty);
    final sources = batch.map((t) => radio.reasonFor(t.id)!.source).toSet();
    expect(sources, containsAll([RadioSource.lastfm, RadioSource.deezer]));
    expect(radio.reasonFor(batch.first.id)!.seedTitle, 'Toxicity');
  });

  test('never repeats the seed, even as another version', () async {
    final radio = _radio();
    final batch = await radio.nextBatch(count: 10);
    expect(batch.map((t) => t.id), isNot(contains('s-remaster')));
  });

  test('prefers the studio version over a live one', () async {
    final radio = _radio();
    final ids = (await radio.nextBatch(count: 10)).map((t) => t.id);
    expect(ids, contains('df'));
    expect(ids, isNot(contains('df-live')));
  });

  test('keeps the same artist apart', () async {
    final radio = _radio();
    final batch = await radio.nextBatch(count: 8);
    for (var i = 1; i < batch.length; i++) {
      expect(batch[i].artistId, isNot(batch[i - 1].artistId),
          reason: 'back-to-back ${batch[i].artistName}');
    }
  });

  test('two quick skips ban an artist for the session', () async {
    final radio = _radio();
    final skipped = _t('x1', 'Song 0-9', 'art0', 'Artist 0');
    radio.registerPlayed(skipped, 0.1);
    radio.registerPlayed(skipped, 0.05);
    expect(radio.isBanned(skipped), isTrue);

    final batch = await radio.nextBatch(count: 10);
    expect(batch.where((t) => t.artistId == 'art0'), isEmpty);
  });

  test('skipping the seed artist never bans it', () {
    final radio = _radio();
    radio.registerPlayed(_seed, 0.1);
    radio.registerPlayed(_seed, 0.1);
    expect(radio.isBanned(_seed), isFalse);
  });

  test('less like this bans immediately', () async {
    final radio = _radio();
    final korn = _t('kn', 'Freak On a Leash', 'korn', 'Korn');
    radio.lessLikeThis(korn);
    final batch = await radio.nextBatch(count: 10);
    expect(batch.where((t) => t.artistId == 'korn'), isEmpty);
  });

  test('songs are unique across batches', () async {
    final radio = _radio();
    final first = await radio.nextBatch(count: 6);
    final second = await radio.nextBatch(count: 6);
    final ids = [...first, ...second].map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('works with Deezer alone when Last.fm is unavailable', () async {
    final radio = SongRadio(
      seed: _seed,
      similar: (_, __) async => throw Exception('no key'),
      artistRadio: _deezerRadio,
      search: _search,
      useLastFm: true,
      random: Random(3),
    );
    final batch = await radio.nextBatch(count: 5);
    expect(batch, isNotEmpty);
    expect(batch.every((t) => radio.reasonFor(t.id)!.source == RadioSource.deezer),
        isTrue);
  });

  test('survives a save/restore round trip with what it learned', () async {
    final radio = _radio(mode: RadioMode.adventurous);
    final first = await radio.nextBatch(count: 4);
    final skipped = _t('x1', 'Song 1-9', 'art1', 'Artist 1');
    radio.registerPlayed(skipped, 0.1);
    radio.registerPlayed(skipped, 0.1);

    final saved = radio.toJson(keepReasonsFor: first.map((t) => t.id));
    final restored = SongRadio.fromJson(
      saved,
      similar: _similar,
      artistRadio: _deezerRadio,
      search: _search,
      useLastFm: true,
      random: Random(7),
    )!;

    expect(restored.seed.id, _seed.id);
    expect(restored.mode, RadioMode.adventurous);
    expect(restored.isBanned(skipped), isTrue);
    expect(restored.reasonFor(first.first.id)?.source,
        radio.reasonFor(first.first.id)?.source);

    final next = await restored.nextBatch(count: 10);
    final firstIds = first.map((t) => t.id).toSet();
    expect(next.where((t) => firstIds.contains(t.id)), isEmpty,
        reason: 'songs heard before the restart must not repeat');
    expect(next.where((t) => t.artistId == 'art1'), isEmpty);
  });

  test('unreadable saved radio data restores nothing', () {
    expect(SongRadio.fromJson({'v': 1}), isNull);
    expect(SongRadio.fromJson({'v': 999, 'seed': _seed.toJson()}), isNull);
  });

  test('norm collapses versions, accents and featured artists', () {
    expect(SongRadio.norm('Toxicity (Remastered)'), 'toxicity');
    expect(SongRadio.norm('Canción - Live at Rock in Rio'), 'cancion');
    expect(SongRadio.norm('Song feat. Someone'), 'song');
    expect(SongRadio.norm('Dancing with Myself'), 'dancing with myself');
  });

  test('PlaybackQueue.dropBefore trims played tracks and keeps position', () {
    final tracks = [for (var i = 0; i < 10; i++) _t('q$i', 'q$i', 'a$i', 'A$i')];
    final q = PlaybackQueue(random: Random(1))..select(tracks[0], newQueue: tracks);
    for (var i = 0; i < 6; i++) {
      q.next(online: true, canPlay: (_) => true);
    }
    expect(q.current!.id, 'q6');

    q.dropBefore(4);
    expect(q.length, 6);
    expect(q.current!.id, 'q6');
    expect(q.currentIndex, 2);
    expect(q.history.every((i) => i >= 0 && i < q.length), isTrue);
  });
}
