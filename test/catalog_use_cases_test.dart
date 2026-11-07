import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist_albums_page.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/music_catalog.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/find_artist_by_name.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_artist_page.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_latest_releases.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/catalog/get_similar_artists.dart';
import 'package:tsuki_tunes_mobile/domain/usecases/library/ensure_album_track_counts.dart';

import 'helpers/fake_library_repository.dart';

Artist _artist(String id, [String? name]) =>
    Artist(id: id, name: name ?? 'Artist $id', pictureUrl: '');

Album _album(String id, String released,
        {String artistId = '', String artistName = 'Unknown Artist'}) =>
    Album(
      id: id,
      title: 'Album $id',
      coverUrl: '',
      artistId: artistId,
      artistName: artistName,
      releaseDate: released,
    );

Track _track(String id, {String artistId = 'a1', String artistName = 'Main'}) => Track(
      id: id,
      title: 'Song $id',
      artistId: artistId,
      artistName: artistName,
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 100,
    );

/// A catalog answering from maps; [failing] ids throw, like Deezer offline.
class _Catalog implements MusicCatalog {
  Map<String, List<Artist>> searches = {};
  Map<String, List<Album>> albums = {};
  Map<String, List<Artist>> related = {};
  Map<String, List<Track>> top = {};
  Map<String, List<Album>> compilations = {};
  Set<String> failing = {};
  bool offline = false;
  final albumsAsked = <String>[];

  void _check(String id) {
    if (offline || failing.contains(id)) throw Exception('offline');
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 25}) async {
    _check(query);
    return (searches[query] ?? const []).take(limit).toList();
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId,
      {int limit = 250, int index = 0}) async {
    _check(artistId);
    return albums[artistId] ?? const [];
  }

  @override
  Future<ArtistAlbumsPage> getArtistAlbumsPage(String artistId,
      {int limit = 50, int index = 0}) async {
    _check(artistId);
    final items = albums[artistId] ?? const <Album>[];
    return ArtistAlbumsPage(
        items: items, total: items.length + 5, hasMore: true, nextIndex: items.length);
  }

  @override
  Future<List<Album>> getArtistCompilations(String artistId, {int limit = 50}) async {
    _check(artistId);
    return compilations[artistId] ?? const [];
  }

  @override
  Future<List<Artist>> getRelatedArtists(String artistId,
      {int limit = 20, bool throwOnError = false}) async {
    _check(artistId);
    return (related[artistId] ?? const []).take(limit).toList();
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId, {int limit = 10}) async {
    _check(artistId);
    return top[artistId] ?? const [];
  }

  @override
  Future<Album?> getAlbum(String albumId) async {
    albumsAsked.add(albumId);
    return null;
  }

  @override
  Future<List<Artist>> getFeaturedArtists() async => const [];

  @override
  Future<List<Track>> enrichTracksWithContributors(List<Track> tracks) async => tracks;

  @override
  Future<Artist?> getArtist(String id) async => null;

  @override
  Future<Track?> getTrack(String trackId, {bool forceRefresh = false}) async => null;

  @override
  Future<List<Track>> getLargeChartTracks() async => const [];

  @override
  Future<List<Track>> searchTracksUnfiltered(String query, {int limit = 25}) async =>
      const [];

  @override
  Future<void> prefetchRelatedArtists(Iterable<String> artistIds) async {}
}

void main() {
  late _Catalog catalog;
  setUp(() => catalog = _Catalog());

  group('find an artist by name', () {
    test('the one named exactly so, else the best match', () async {
      catalog.searches['korn'] = [_artist('1', 'Korn Tribute'), _artist('2', 'Korn')];
      catalog.searches['deftones'] = [_artist('3', 'Deftones Live')];
      final find = FindArtistByName(catalog);
      expect((await find('korn'))!.id, '2');
      expect((await find('deftones'))!.id, '3');
      expect(await find('nobody'), isNull);
      expect(await find('  '), isNull);
    });

    test('null when the catalog can\'t be reached', () async {
      catalog.offline = true;
      expect(await FindArtistByName(catalog)('korn'), isNull);
    });
  });

  group('latest releases', () {
    final now = DateTime(2026, 11, 7);

    test('from the last year, newest first, each once, with their artist',
        () async {
      catalog.albums = {
        'a': [_album('new', '2026-10-01'), _album('old', '2025-01-01'), _album('mid', '2026-03-01')],
        'b': [_album('new', '2026-10-01'), _album('b1', '2026-06-15', artistId: 'b', artistName: 'Real')],
      };
      final releases = await GetLatestReleases(catalog, now: () => now)(
          [_artist('a', 'Alpha'), _artist('b', 'Beta')]);
      expect(releases.map((a) => a.id), ['new', 'b1', 'mid']);
      expect(releases.first.artistName, 'Alpha');
      expect(releases.first.artistId, 'a');
      expect(releases[1].artistName, 'Real', reason: 'a known artist is kept');
    });

    test('an artist that fails to load is skipped', () async {
      catalog.albums = {'b': [_album('b1', '2026-06-15')]};
      catalog.failing = {'a'};
      final releases = await GetLatestReleases(catalog, now: () => now)(
          [_artist('a'), _artist('b')]);
      expect(releases.single.id, 'b1');
    });

    test('at most [limit]', () async {
      catalog.albums = {
        'a': [for (var i = 1; i <= 9; i++) _album('x$i', '2026-0$i-01')],
      };
      final releases =
          await GetLatestReleases(catalog, now: () => now)([_artist('a')], limit: 3);
      expect(releases.map((a) => a.id), ['x9', 'x8', 'x7']);
    });
  });

  test('similar artists: each once, never a seed or someone excluded', () async {
    catalog.related = {
      's1': [_artist('x'), _artist('s2'), _artist('y')],
      's2': [_artist('y'), _artist('z'), _artist('shown')],
    };
    final similar = await GetSimilarArtists(catalog)(
      [_artist('s1'), _artist('s2')],
      exclude: {'shown'},
    );
    expect(similar.map((a) => a.id), ['x', 'y', 'z']);
  });

  group('artist page', () {
    test('own songs and features apart, compilations once, tags', () async {
      catalog.top['a1'] = [
        _track('own1'),
        _track('feat', artistId: 'other', artistName: 'Other feat. Main'),
        _track('own2'),
      ];
      catalog.albums['a1'] = [_album('r1', '2020-01-01'), _album('c1', '2021-01-01')];
      catalog.compilations['a1'] = [_album('c1', '2021-01-01'), _album('c2', '2022-01-01')];
      catalog.related['a1'] = [_artist('sim')];
      final page = await GetArtistPage(catalog, tags: (_) async => ['nu metal'])(
          _artist('a1', 'Main'));
      expect(page.topTracks.map((t) => t.id), ['own1', 'own2']);
      expect(page.albums.map((a) => a.id), ['r1', 'c1', 'c2']);
      expect(page.totalAlbums, 2 + 5 + 1, reason: 'the page total plus new compilations');
      expect(page.hasMoreAlbums, isTrue);
      expect(page.tags, ['nu metal']);
      expect(page.related.single.id, 'sim');
    });

    test('failing tags leave the page without them; an offline catalog throws',
        () async {
      final page = await GetArtistPage(catalog,
          tags: (_) async => throw Exception('no key'))(_artist('a1'));
      expect(page.tags, isEmpty);

      catalog.offline = true;
      await expectLater(
          GetArtistPage(catalog, tags: (_) async => const [])(_artist('a1')),
          throwsA(anything));
    });
  });

  test('album song counts are asked of the library with the catalog', () {
    final library = FakeLibraryRepository();
    EnsureAlbumTrackCounts(library, catalog)([_album('x', ''), _album('y', '')]);
    expect(library.countsAsked, ['x', 'y']);
  });
}
