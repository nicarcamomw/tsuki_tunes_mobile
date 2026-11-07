import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/music_catalog.dart';
import 'package:tsuki_tunes_mobile/presentation/state/discovery_controller.dart';

Track _t(String id, {bool preview = true}) => Track(
      id: id,
      title: 'Song $id',
      artistName: 'Artist',
      artistId: 'x',
      albumId: 'al',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: preview ? 'https://p/$id.mp3' : '',
      durationSeconds: 200,
    );

Artist _a(String id) => Artist(id: id, name: 'Artist $id', pictureUrl: '');

class _Catalog implements MusicCatalog {
  int chartCalls = 0;
  bool offline = false;

  @override
  Future<List<Artist>> getRelatedArtists(String artistId, {int limit = 20, bool throwOnError = false}) async {
    if (offline) return [];
    return [for (var i = 0; i < 5; i++) _a('$artistId-r$i')];
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId, {int limit = 10}) async =>
      [for (var i = 0; i < 6; i++) _t('$artistId-t$i', preview: i != 0)];

  @override
  Future<List<Track>> getLargeChartTracks() async {
    chartCalls++;
    if (offline) return [];
    return [for (var i = 0; i < 20; i++) _t('chart$i')];
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 25}) async => [_a('found-$query')];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  DiscoveryController deck(_Catalog c, {List<Artist> known = const [], Set<String> listened = const {}}) =>
      DiscoveryController(
        catalog: c,
        knownArtists: () => known,
        topArtistNames: () => const [],
        isListened: listened.contains,
        random: Random(1),
      );

  test('fills from artists near the ones you love, never a song without preview or already heard', () async {
    final d = deck(_Catalog(), known: [_a('soad')], listened: {'soad-r0-t1'});
    await d.start();
    expect(d.cards.length, greaterThanOrEqualTo(DiscoveryController.ahead));
    for (final c in d.cards) {
      expect(c.track.previewUrl, isNotEmpty);
      expect(c.track.id, isNot('soad-r0-t1'));
      if (c.because != null) expect(c.because, 'Artist soad');
    }
    expect(d.cards.map((c) => c.track.id).toSet().length, d.cards.length, reason: 'no repeats');
  });

  test('with nothing to start from, the charts', () async {
    final c = _Catalog();
    final d = deck(c);
    await d.start();
    expect(c.chartCalls, 1);
    expect(d.cards.every((c) => c.because == null), isTrue);
  });

  test('an answered song never comes back, even in a new deck', () async {
    final d = deck(_Catalog());
    await d.start();
    final first = d.cards.first;
    d.answer(first, liked: true);
    expect(d.liked, 1);
    expect(d.cards.contains(first), isFalse);
    await Future<void>.delayed(Duration.zero);
    final again = deck(_Catalog());
    await again.start();
    expect(again.cards.map((c) => c.track.id), isNot(contains(first.track.id)));
  });

  test('offline it runs dry and says so, and can try again', () async {
    final c = _Catalog()..offline = true;
    final d = deck(c, known: [_a('soad')]);
    await d.start();
    expect(d.exhausted, isTrue);
    c.offline = false;
    await d.retry();
    expect(d.exhausted, isFalse);
    expect(d.cards, isNotEmpty);
  });
}
