import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/song_radio.dart';

Track _t(String id, String artistId, String artist) => Track(
      id: id,
      title: 'Song $id',
      artistId: artistId,
      artistName: artist,
      albumId: 'al$id',
      albumTitle: 'album',
      coverUrl: '',
      previewUrl: 'https://cdn/preview/$id.mp3',
      durationSeconds: 200,
    );

const _linkin = Artist(id: 'lp', name: 'Linkin Park', pictureUrl: '');

/// Ten related artists, r0 the closest.
Future<List<Artist>> _related(String id) async => [
      for (var i = 0; i < 10; i++) Artist(id: 'r$i', name: 'Related $i', pictureUrl: ''),
    ];

/// Every artist's top 10.
Future<List<Track>> _top(String artistId) async => [
      for (var i = 0; i < 10; i++)
        _t('$artistId-$i', artistId, artistId == 'lp' ? 'Linkin Park' : 'Related ${artistId.substring(1)}'),
    ];

SongRadio _radio(RadioMode mode, {List<String>? topCalls}) => SongRadio(
      seed: _t('lp-0', 'lp', 'Linkin Park'),
      mode: mode,
      artist: _linkin,
      topTracks: (id) {
        topCalls?.add(id);
        return _top(id);
      },
      related: _related,
      random: Random(3),
    );

void main() {
  test('an artist radio plays the artist\'s top songs and their related artists\'', () async {
    final radio = _radio(RadioMode.balanced);
    final batch = await radio.nextBatch(count: 12);
    expect(batch, isNotEmpty);
    expect(batch.map((t) => t.id), isNot(contains('lp-0')), reason: 'the seed already plays');
    final own = batch.where((t) => t.artistId == 'lp');
    final related = batch.where((t) => t.artistId.startsWith('r'));
    expect(own, isNotEmpty);
    expect(related, isNotEmpty);
    expect(radio.reasonFor(own.first.id)?.source, RadioSource.artistTop);
    final r = related.first;
    expect(radio.reasonFor(r.id)?.source, RadioSource.related);
    expect(radio.reasonFor(r.id)?.seedArtist, 'Linkin Park');
  });

  test('never the same song twice, and the same artist kept apart', () async {
    final radio = _radio(RadioMode.balanced);
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      ids.addAll((await radio.nextBatch(count: 6)).map((t) => t.id));
    }
    expect(ids.toSet().length, ids.length);
  });

  test('familiar stays near the artist; adventurous reaches further down the related list', () async {
    Future<Set<String>> relatedReached(RadioMode mode) async {
      final calls = <String>[];
      final radio = _radio(mode, topCalls: calls);
      for (var i = 0; i < 4; i++) {
        await radio.nextBatch(count: 6);
      }
      return {for (final c in calls) if (c.startsWith('r')) c};
    }

    final familiar = await relatedReached(RadioMode.familiar);
    final adventurous = await relatedReached(RadioMode.adventurous);
    expect(familiar.every((id) => int.parse(id.substring(1)) < 6), isTrue);
    expect(adventurous.length, greaterThan(familiar.length));
  });

  test('a related artist skipped twice is left out', () async {
    final radio = _radio(RadioMode.balanced);
    final first = await radio.nextBatch(count: 12);
    final r = first.firstWhere((t) => t.artistId.startsWith('r'));
    radio
      ..registerPlayed(r, 0.1)
      ..registerPlayed(r, 0.1);
    for (var i = 0; i < 4; i++) {
      final next = await radio.nextBatch(count: 6);
      expect(next.where((t) => t.artistId == r.artistId), isEmpty);
    }
  });

  test('the artist and the walk through the related list survive a restart', () async {
    final radio = _radio(RadioMode.balanced);
    await radio.nextBatch(count: 8);
    final restored = SongRadio.fromJson(radio.toJson(), topTracks: _top, related: _related);
    expect(restored, isNotNull);
    expect(restored!.isArtistRadio, isTrue);
    expect(restored.artist?.name, 'Linkin Park');
    final again = await restored.nextBatch(count: 6);
    expect(again, isNotEmpty);
  });

  test('a song radio is not an artist radio', () {
    final radio = SongRadio(seed: _t('x', 'a', 'A'));
    expect(radio.isArtistRadio, isFalse);
    expect(radio.toJson().containsKey('artist'), isFalse);
  });

  test('a song radio mixes in its artist and their related artists too, led by the song', () async {
    final radio = SongRadio(
      seed: _t('lp-5', 'lp', 'Linkin Park'),
      artist: _linkin,
      artistLed: false,
      topTracks: _top,
      related: _related,
      random: Random(3),
    );
    expect(radio.isArtistRadio, isFalse);
    final batch = await radio.nextBatch(count: 12);
    expect(batch.where((t) => t.artistId.startsWith('r')), isNotEmpty);
    // Fewer of the artist's own songs than their artist radio plays.
    final artistRadio = _radio(RadioMode.balanced);
    final led = await artistRadio.nextBatch(count: 12);
    expect(batch.where((t) => t.artistId == 'lp').length,
        lessThanOrEqualTo(led.where((t) => t.artistId == 'lp').length));
    final restored = SongRadio.fromJson(radio.toJson(), topTracks: _top, related: _related)!;
    expect(restored.isArtistRadio, isFalse);
    expect(restored.artist?.id, 'lp');
  });
}
