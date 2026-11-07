import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../core/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/artist_albums_page.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/genre_catalog.dart';
import '../../domain/repositories/music_catalog.dart';
import '../contracts/music_api_contract.dart';
import 'deezer_disk_cache.dart';
import 'perf_tracker.dart';


final _log = Log.named('DeezerAPI');

/// Top-level so it can be sent to an isolate via [compute].
dynamic _decodeJson(String source) => json.decode(source);

/// Threshold in bytes above which JSON decoding runs in an isolate.
const int _isolateThreshold = 10 * 1024;

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;
  _CacheEntry(this.data, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class TrackAudioInfo {
  final double bpm;
  /// Deezer's loudness measure in dB: higher (less negative) is louder.
  final double? gain;

  const TrackAudioInfo({required this.bpm, this.gain});
}

class DeezerApiService
    implements MusicApiContract, MusicCatalog, GenreCatalog {
  static final DeezerApiService _instance = DeezerApiService._internal();
  factory DeezerApiService() => _instance;
  DeezerApiService._internal();

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future> _inFlight = {};
  final DeezerDiskCache _diskCache = DeezerDiskCache();

  static const int _searchTtlMinutes = 120;
  static const int _chartTtlMinutes = 60;
  static const int _entityTtlMinutes = 1440;
  static const int _minArtistFans = 5000;
  static const int _minTrackRank = 10000;

  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?url=',
  ];

  void _pruneCache() {
    _cache.removeWhere((_, entry) => entry.isExpired);
    if (_cache.length > 200) {
      final sorted = _cache.entries.toList()
        ..sort((a, b) => a.value.expiry.compareTo(b.value.expiry));
      final removeCount = (_cache.length * 0.3).ceil();
      for (var i = 0; i < removeCount && i < sorted.length; i++) {
        _cache.remove(sorted[i].key);
      }
    }
  }

  T? _getCached<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) return entry.data as T;
    if (entry != null) _cache.remove(key);
    return null;
  }

  Future<T?> _loadFromDisk<T>(String key) async {
    if (!_diskCache.isReady) return null;
    final entry = await _diskCache.read(key);
    if (entry == null) return null;
    try {
      final data = DeezerDiskCache.deserialize(entry.type, entry.data);
      if (data is T) {
        _cache[key] = _CacheEntry(data, entry.expiry);
        return data;
      }
    } catch (e) {
      _log.severe('disk deserialize error ($key): $e');
    }
    return null;
  }

  Future<T?> _getFromCache<T>(String key) async {
    return _getCached<T>(key) ?? await _loadFromDisk<T>(key);
  }

  void _setCache(String key, dynamic data,
      {bool isSearch = false, bool isChart = false}) {
    _pruneCache();
    final ttl =
        isSearch ? _searchTtlMinutes : (isChart ? _chartTtlMinutes : _entityTtlMinutes);
    final expiry = DateTime.now().add(Duration(minutes: ttl));
    _cache[key] = _CacheEntry(data, expiry);

    final typeTag = DeezerDiskCache.typeTagFor(data);
    if (typeTag != null) {
      final serialized = DeezerDiskCache.serialize(typeTag, data);
      if (serialized != null) {
        _diskCache.write(key, typeTag, serialized, expiry);
      }
    }
  }

  /// Decodes [body] on an isolate when it is large enough to jank the UI.
  static Future<dynamic> _decode(String body) {
    if (body.length >= _isolateThreshold) return compute(_decodeJson, body);
    return Future.value(json.decode(body));
  }

  /// Fetches JSON from [url]. Returns decoded data on success.
  /// Returns `null` for entity lookups (getArtist, getTrack, etc.).
  /// Throws [DeezerApiException] for search/chart operations that need error propagation.
  Future<dynamic> _fetchJson(String url, {bool throwOnError = false}) async {
    if (!kIsWeb) {
      // Mobile/desktop: direct call, no CORS proxies needed. Each request is
      // timed by endpoint in Firebase Performance (PerfTracker).
      final uri = Uri.parse(url);
      Future<http.Response> get() => PerfTracker.instance.request(
          'GET', uri, () => http.get(uri).timeout(const Duration(seconds: 10)));
      try {
        var res = await get();

        // Auto-recovery for HTTP 429 Too Many Requests (Deezer rate limit)
        if (res.statusCode == 429) {
          _log.warning('HTTP 429 rate limit for $url. Waiting 1s before retry...');
          await Future.delayed(const Duration(milliseconds: 1000));
          res = await get();
        }

        if (res.statusCode == 200) {
          final decoded = await _decode(res.body);
          if (decoded is Map<String, dynamic> && decoded['error'] != null) {
            final errCode = decoded['error']['code'];
            if (errCode == 4 || errCode == 800) {
              _log.warning('Quota limit code $errCode for $url. Waiting 1s before retry...');
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryRes = await get();
              if (retryRes.statusCode == 200) {
                final retryDecoded = await _decode(retryRes.body);
                if (retryDecoded is Map<String, dynamic> && retryDecoded['error'] == null) {
                  return retryDecoded;
                }
              }
            }
            final msg = '[DeezerAPI] Error in response for $url: ${decoded['error']}';
            _log.info(msg);
            if (throwOnError) throw DeezerApiException(msg);
            return null;
          }
          return decoded;
        }

        final msg = '[DeezerAPI] HTTP ${res.statusCode} for $url';
        _log.info(msg);
        if (throwOnError) throw DeezerApiException(msg);
      } catch (e) {
        if (e is DeezerApiException) rethrow;
        final msg = '[DeezerAPI] Network error for $url: $e';
        _log.info(msg);
        if (throwOnError) throw DeezerApiException(msg);
      }
      return null;
    }

    // Web: try CORS proxies first, then direct
    for (final proxy in _corsProxies) {
      try {
        final proxyUrl = '$proxy${Uri.encodeComponent(url)}';
        final res = await http
            .get(Uri.parse(proxyUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) return await _decode(res.body);
      } catch (e) {
        if (e is DeezerApiException) rethrow;
        _log.severe('CORS proxy error: $e');
      }
    }

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return await _decode(res.body);
    } catch (e) {
      if (e is DeezerApiException) rethrow;
      final msg = '[DeezerAPI] Direct web fetch error for $url: $e';
      _log.info(msg);
      if (throwOnError) throw DeezerApiException(msg);
    }

    if (throwOnError) throw DeezerApiException('[DeezerAPI] All fetch attempts failed for $url');
    return null;
  }

  Future<T> _deduped<T>(String key, Future<T> Function() fetcher) async {
    if (_inFlight.containsKey(key)) {
      return await _inFlight[key] as T;
    }
    final future = fetcher();
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlight.remove(key));
    }
  }

  // --- Parallel search (like web: 3 endpoints) ---

  /// Parallel search across artists, albums, and tracks.
  /// Throws [DeezerApiException] on network/API failures so callers can show error states.
  Future<Map<String, dynamic>> search(String query) async {
    if (query.trim().length < 2) {
      return {'tracks': <Track>[], 'artists': <Artist>[], 'albums': <Album>[]};
    }

    final cacheKey = 'search_$query';
    final cached = await _getFromCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      final results = await Future.wait([
        searchArtists(query),
        searchAlbums(query),
        searchTracks(query),
      ]);

      final result = {
        'artists': results[0] as List<Artist>,
        'albums': results[1] as List<Album>,
        'tracks': results[2] as List<Track>,
      };

      _setCache(cacheKey, result, isSearch: true);
      return result;
    });
  }

  /// Throws [DeezerApiException] on failure so search() can propagate errors.
  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 25}) async {
    final cacheKey = 'search_artists_$query';
    final cached = await _getFromCache<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    final data = await _fetchJson(
      ApiEndpoints.searchArtists(query, limit: limit),
      throwOnError: true,
    );
    if (data is Map<String, dynamic>) {
      final List items = data['data'] ?? [];
      final all = items.map((item) => Artist.fromDeezer(item)).toList();
      final filtered = all.where((a) => a.fansCount >= _minArtistFans).toList();
      final artists = filtered.isNotEmpty ? filtered : all;
      _setCache(cacheKey, artists, isSearch: true);
      return artists;
    }
    return [];
  }

  /// Throws [DeezerApiException] on failure so search() can propagate errors.
  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final cacheKey = 'search_albums_$query';
    final cached = await _getFromCache<List<Album>>(cacheKey);
    if (cached != null) return cached;

    final data = await _fetchJson(
      ApiEndpoints.searchAlbums(query, limit: limit),
      throwOnError: true,
    );
    if (data is Map<String, dynamic>) {
      final List items = data['data'] ?? [];
      final albums = items.map((item) => Album.fromDeezer(item)).toList();
      _setCache(cacheKey, albums, isSearch: true);
      return albums;
    }
    return [];
  }

  /// Throws [DeezerApiException] on failure so search() can propagate errors.
  @override
  Future<List<Track>> searchTracks(String query, {int limit = 25}) =>
      _searchTracks(query, limit: limit, dropUnpopular: true);

  /// Like [searchTracks] but keeps low-rank tracks, for when the user is
  /// looking for one specific song (e.g. a guess in the guess-the-song game).
  Future<List<Track>> searchTracksUnfiltered(String query, {int limit = 25}) =>
      _searchTracks(query, limit: limit, dropUnpopular: false);

  Future<List<Track>> _searchTracks(String query,
      {required int limit, required bool dropUnpopular}) async {
    // The limit and filter are part of the key: a 6-result lookup must not
    // be served to a caller asking for 25.
    final cacheKey = 'search_tracks_${limit}_${dropUnpopular ? 'f' : 'u'}_$query';
    final cached = await _getFromCache<List<Track>>(cacheKey);
    if (cached != null) return cached;

    final data = await _fetchJson(
      ApiEndpoints.searchTracks(query, limit: limit),
      throwOnError: true,
    );
    if (data is Map<String, dynamic>) {
      final List items = data['data'] ?? [];
      final all = items.map((item) => Track.fromDeezer(item)).toList();
      var tracks = all;
      if (dropUnpopular) {
        final filtered = all.where((t) => t.rank == null || t.rank! >= _minTrackRank).toList();
        if (filtered.isNotEmpty) tracks = filtered;
      }
      _setCache(cacheKey, tracks, isSearch: true);
      return tracks;
    }
    return [];
  }

  // --- Legacy single-endpoint search (kept for compatibility) ---

  Future<Map<String, dynamic>> searchAll(String query) => search(query);

  // --- Entity fetchers ---

  @override
  Future<List<Track>> getChartTracks() async {
    const cacheKey = 'chart_tracks';
    final cached = await _getFromCache<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.chartTracks);
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final tracks = list.map((item) => Track.fromDeezer(item)).toList();
        _setCache(cacheKey, tracks, isChart: true);
        return tracks;
      }
    } catch (e) {
      _log.severe('getChartTracks error: $e');
    }
    return [];
  }

  /// Tempo and loudness of a track, only returned by /track/{id}. A bpm of 0
  /// means Deezer doesn't know it; null means the request failed (worth
  /// retrying later).
  Future<TrackAudioInfo?> getTrackAudioInfo(String trackId) async {
    try {
      final data = await _fetchJson(ApiEndpoints.track(trackId));
      if (data is Map<String, dynamic> && data['error'] == null && data['id'] != null) {
        final bpm = data['bpm'];
        final gain = data['gain'];
        return TrackAudioInfo(
          bpm: bpm is num ? bpm.toDouble() : 0,
          gain: gain is num && gain != 0 ? gain.toDouble() : null,
        );
      }
    } catch (e) {
      _log.severe('getTrackAudioInfo($trackId) error: $e');
    }
    return null;
  }

  /// Top 100 global tracks; the guess-the-song game needs a bigger pool than
  /// the home chart.
  Future<List<Track>> getLargeChartTracks() async {
    const cacheKey = 'chart_tracks_large';
    final cached = await _getFromCache<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.chartTracksLarge);
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final tracks = list.map((item) => Track.fromDeezer(item)).toList();
        _setCache(cacheKey, tracks, isChart: true);
        return tracks;
      }
    } catch (e) {
      _log.severe('getLargeChartTracks error: $e');
    }
    return [];
  }

  @override
  Future<List<Artist>> getChartArtists() async {
    const cacheKey = 'chart_artists';
    final cached = await _getFromCache<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.chartArtists);
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final artists = list.map((item) => Artist.fromDeezer(item)).toList();
        _setCache(cacheKey, artists, isChart: true);
        return artists;
      }
    } catch (e) {
      _log.severe('getChartArtists error: $e');
    }
    return [];
  }

  /// Deezer's music genres, without "All". Kept in memory only (the disk
  /// cache doesn't know the type); empty when they can't be reached.
  @override
  Future<List<Genre>> getGenres() async {
    const cacheKey = 'genres';
    final cached = _getCached<List<Genre>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.genres);
        if (data is Map<String, dynamic>) {
          final List list = data['data'] ?? [];
          final genres = list
              .whereType<Map<String, dynamic>>()
              .map(Genre.fromDeezer)
              .where((g) => g.id.isNotEmpty && g.id != '0' && g.name.isNotEmpty)
              .toList();
          if (genres.isNotEmpty) _setCache(cacheKey, genres, isChart: true);
          return genres;
        }
      } catch (e) {
        _log.severe('getGenres error: $e');
      }
      return <Genre>[];
    });
  }

  /// The best known artists of a genre. Throws [DeezerApiException] when
  /// Deezer can't be reached, so the genre page can offer a retry.
  @override
  Future<List<Artist>> getGenreArtists(String genreId) async {
    final cacheKey = 'genre_artists_$genreId';
    final cached = await _getFromCache<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      final data = await _fetchJson(ApiEndpoints.genreArtists(genreId),
          throwOnError: true);
      if (data is! Map<String, dynamic>) return <Artist>[];
      final List list = data['data'] ?? [];
      final artists = list
          .map((item) => Artist.fromDeezer(item))
          .where((a) => a.id.isNotEmpty)
          .toList();
      _setCache(cacheKey, artists, isChart: true);
      return artists;
    });
  }

  /// The genre's most played songs right now. Throws like
  /// [getGenreArtists].
  @override
  Future<List<Track>> getGenreChartTracks(String genreId) async {
    final cacheKey = 'genre_tracks_$genreId';
    final cached = await _getFromCache<List<Track>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      final data = await _fetchJson(ApiEndpoints.genreChartTracks(genreId),
          throwOnError: true);
      if (data is! Map<String, dynamic>) return <Track>[];
      final List list = data['data'] ?? [];
      final tracks = list
          .map((item) => Track.fromDeezer(item))
          .where((t) => t.id.isNotEmpty)
          .toList();
      _setCache(cacheKey, tracks, isChart: true);
      return tracks;
    });
  }

  @override
  Future<List<Artist>> getFeaturedArtists() async {
    const cacheKey = 'featured_artists';
    final cached = await _getFromCache<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    final List<Artist> results = [];
    final futures = ApiEndpoints.featuredArtistIds.map((id) => getArtist(id));
    final artists = await Future.wait(futures);
    for (final artist in artists) {
      if (artist != null) results.add(artist);
    }

    if (results.isNotEmpty) _setCache(cacheKey, results);
    return results;
  }

  @override
  Future<List<Artist>> getArtists(List<String> ids) async {
    final futures = ids.map((id) => getArtist(id));
    final results = await Future.wait(futures);
    return results.whereType<Artist>().toList();
  }

  @override
  Future<Artist?> getArtist(String id) async {
    final cacheKey = 'artist_$id';
    final cached = await _getFromCache<Artist>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.artist(id));
        if (data is Map<String, dynamic>) {
          final artist = Artist.fromDeezer(data);
          _setCache(cacheKey, artist);
          return artist;
        }
      } catch (e) {
        _log.severe('getArtist($id) error: $e');
      }
      return null;
    });
  }

  @override
  Future<List<Track>> getArtistTopTracks(String artistId,
      {int limit = 10}) async {
    final cacheKey = 'artist_top_${artistId}_$limit';
    final cached = await _getFromCache<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data =
          await _fetchJson(ApiEndpoints.artistTopTracks(artistId, limit: limit));
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final tracks = list.map((item) => Track.fromDeezer(item)).toList();
        _setCache(cacheKey, tracks);
        return tracks;
      }
    } catch (e) {
      _log.severe('getArtistTopTracks($artistId) error: $e');
    }
    return [];
  }

  @override
  Future<ArtistAlbumsPage> getArtistAlbumsPage(
    String artistId, {
    int limit = 50,
    int index = 0,
  }) async {
    final cacheKey = 'artist_albums_page_${artistId}_${limit}_$index';
    final cached = await _getFromCache<ArtistAlbumsPage>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(
            ApiEndpoints.artistAlbums(artistId, limit: limit, index: index));
        if (data is Map<String, dynamic>) {
          final List list = data['data'] ?? [];
          final items = list.map((item) {
            final album = Album.fromDeezer(item);
            if (album.artistId.isEmpty) {
              return album.copyWith(artistId: artistId);
            }
            return album;
          }).toList();
          final int total =
              (data['total'] is int) ? data['total'] : items.length;
          final bool hasMore =
              (index + items.length) < total && items.isNotEmpty;
          final page = ArtistAlbumsPage(
            items: items,
            total: total,
            hasMore: hasMore,
            nextIndex: index + items.length,
          );
          _setCache(cacheKey, page);
          return page;
        }
      } catch (e) {
        _log.severe('getArtistAlbumsPage($artistId, index: $index) error: $e');
      }
      return ArtistAlbumsPage.empty;
    });
  }

  @override
  Future<List<Album>> getArtistCompilations(String artistId,
      {int limit = 50}) async {
    final cacheKey = 'artist_compilations_$artistId';
    final cached = await _getFromCache<List<Album>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(
            ApiEndpoints.artistCompilations(artistId, limit: limit));
        if (data is Map<String, dynamic>) {
          final List list = data['data'] ?? [];
          final items = list.map((item) {
            final album = Album.fromDeezer(item);
            return album.copyWith(recordType: 'compile');
          }).toList();
          _setCache(cacheKey, items);
          return items;
        }
      } catch (e) {
        _log.severe('getArtistCompilations($artistId) error: $e');
      }
      return <Album>[];
    });
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId,
      {int limit = 250, int index = 0}) async {
    final cacheKey = 'artist_albums_${artistId}_${limit}_$index';
    final cached = await _getFromCache<List<Album>>(cacheKey);
    if (cached != null) return cached;

    if (index == 0) {
      final oldCached = await _getFromCache<List<Album>>('artist_albums_$artistId');
      if (oldCached != null) return oldCached;
    }

    try {
      final page =
          await getArtistAlbumsPage(artistId, limit: limit, index: index);
      if (index == 0) {
        _setCache('artist_albums_$artistId', page.items);
      }
      _setCache(cacheKey, page.items);
      return page.items;
    } catch (e) {
      _log.severe('getArtistAlbums($artistId) error: $e');
    }
    return [];
  }

  @override
  Future<Album?> getAlbum(String albumId) async {
    final cacheKey = 'album_$albumId';
    final cached = await _getFromCache<Album>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.album(albumId));
        if (data is Map<String, dynamic>) {
          final album = Album.fromDeezer(data);
          _setCache(cacheKey, album);
          return album;
        }
      } catch (e) {
        _log.severe('getAlbum($albumId) error: $e');
      }
      return null;
    });
  }

  @override
  Future<Track?> getTrack(String trackId, {bool forceRefresh = false}) async {
    final cacheKey = 'track_$trackId';
    final cached = forceRefresh ? null : await _getFromCache<Track>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.track(trackId));
        if (data is Map<String, dynamic>) {
          final track = Track.fromDeezer(data);
          _setCache(cacheKey, track);
          return track;
        }
      } catch (e) {
        _log.severe('getTrack($trackId) error: $e');
      }
      return null;
    });
  }

  static const int _relatedFetchLimit = 25;

  /// Artists similar to [artistId]. Always fetched at full size and sliced,
  /// so the artist page, the home and the rabbit hole share one request and
  /// one cache entry whatever [limit] they ask for. Failures return an empty
  /// list unless [throwOnError] is set, for callers that need to tell "no
  /// related artists" from "no network".
  @override
  Future<List<Artist>> getRelatedArtists(String artistId,
      {int limit = 20, bool throwOnError = false}) async {
    final cacheKey = 'artist_related_$artistId';
    final cached = await _getFromCache<List<Artist>>(cacheKey);
    if (cached != null) return cached.take(limit).toList();

    try {
      final all = await _deduped(cacheKey, () async {
        final data = await _fetchJson(
          ApiEndpoints.artistRelated(artistId, limit: _relatedFetchLimit),
          throwOnError: true,
        );
        final List list =
            (data is Map<String, dynamic> ? data['data'] as List? : null) ?? [];
        final artists = list
            .map((item) => Artist.fromDeezer(item))
            .where((a) => a.id.isNotEmpty && a.id != artistId)
            .toList();
        _setCache(cacheKey, artists);
        return artists;
      });
      return all.take(limit).toList();
    } catch (e) {
      _log.severe('getRelatedArtists($artistId) error: $e');
      if (throwOnError) rethrow;
      return <Artist>[];
    }
  }

  /// Warms the cache for [artistIds] one at a time, so the next tap on any
  /// of them answers instantly without bursting Deezer's rate limit.
  Future<void> prefetchRelatedArtists(Iterable<String> artistIds) async {
    for (final id in artistIds) {
      if (_getCached<List<Artist>>('artist_related_$id') != null) continue;
      await getRelatedArtists(id);
    }
  }

  /// Deezer's mix of this artist and similar ones. Not cached: each call
  /// returns a different selection, which keeps song radios fresh.
  Future<List<Track>> getArtistRadio(String artistId, {int limit = 25}) async {
    try {
      final data =
          await _fetchJson(ApiEndpoints.artistRadio(artistId, limit: limit));
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        return list.map((item) => Track.fromDeezer(item)).toList();
      }
    } catch (e) {
      _log.severe('getArtistRadio($artistId) error: $e');
    }
    return <Track>[];
  }

  @override
  Future<List<Track>> enrichTracksWithContributors(List<Track> tracks) async {
    final enriched = <Track>[];
    const batchSize = 8;

    for (var i = 0; i < tracks.length; i += batchSize) {
      final batch = tracks.sublist(
          i, i + batchSize > tracks.length ? tracks.length : i + batchSize);
      final futures = batch.map((t) => getTrack(t.id));
      final results = await Future.wait(futures);

      for (var j = 0; j < batch.length; j++) {
        final full = results[j];
        if (full != null && full.contributors.isNotEmpty) {
          enriched.add(batch[j].copyWith(
            contributors: full.contributors,
            artistName: full.fullArtistName,
          ));
        } else {
          enriched.add(batch[j]);
        }
      }
    }

    return enriched;
  }

  @override
  void clearCache() {
    _cache.clear();
    unawaited(_diskCache.clear());
  }
}

/// Custom exception for Deezer API errors — allows callers to distinguish
/// network/API failures from "no results found" (empty list).
class DeezerApiException implements Exception {
  final String message;
  DeezerApiException(this.message);

  @override
  String toString() => 'DeezerApiException: $message';
}
