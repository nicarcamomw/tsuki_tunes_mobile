import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_endpoints.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;
  _CacheEntry(this.data, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class DeezerApiService {
  static final DeezerApiService _instance = DeezerApiService._internal();
  factory DeezerApiService() => _instance;
  DeezerApiService._internal();

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future> _inFlight = {};

  static const int _searchTtlMinutes = 120;
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

  void _setCache(String key, dynamic data, {bool isSearch = false}) {
    _pruneCache();
    final ttl = isSearch ? _searchTtlMinutes : _entityTtlMinutes;
    _cache[key] = _CacheEntry(data, DateTime.now().add(Duration(minutes: ttl)));
  }

  Future<dynamic> _fetchJson(String url) async {
    if (!kIsWeb) {
      // Mobile/desktop: direct call, no CORS proxies needed
      try {
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) return json.decode(res.body);
        debugPrint('[DeezerAPI] HTTP ${res.statusCode} for $url');
      } catch (e) {
        debugPrint('[DeezerAPI] Network error for $url: $e');
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
        if (res.statusCode == 200) return json.decode(res.body);
      } catch (e) {
        debugPrint('[DeezerAPI] CORS proxy error: $e');
      }
    }

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return json.decode(res.body);
    } catch (e) {
      debugPrint('[DeezerAPI] Direct web fetch error for $url: $e');
    }

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
      _inFlight.remove(key);
    }
  }

  // --- Parallel search (like web: 3 endpoints) ---

  Future<Map<String, dynamic>> search(String query) async {
    if (query.trim().length < 2) {
      return {'tracks': <Track>[], 'artists': <Artist>[], 'albums': <Album>[]};
    }

    final cacheKey = 'search_$query';
    final cached = _getCached<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
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
      } catch (_) {
        return {
          'tracks': <Track>[],
          'artists': <Artist>[],
          'albums': <Album>[]
        };
      }
    });
  }

  Future<List<Artist>> searchArtists(String query, {int limit = 25}) async {
    final cacheKey = 'search_artists_$query';
    final cached = _getCached<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.searchArtists(query, limit: limit));
      if (data is Map<String, dynamic>) {
        final List items = data['data'] ?? [];
        final all = items.map((item) => Artist.fromJson(item)).toList();
        final filtered = all.where((a) => a.fansCount >= _minArtistFans).toList();
        final artists = filtered.isNotEmpty ? filtered : all;
        _setCache(cacheKey, artists, isSearch: true);
        return artists;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] searchArtists error: $e');
    }
    return [];
  }

  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final cacheKey = 'search_albums_$query';
    final cached = _getCached<List<Album>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.searchAlbums(query, limit: limit));
      if (data is Map<String, dynamic>) {
        final List items = data['data'] ?? [];
        final albums = items.map((item) => Album.fromJson(item)).toList();
        _setCache(cacheKey, albums, isSearch: true);
        return albums;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] searchAlbums error: $e');
    }
    return [];
  }

  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    final cacheKey = 'search_tracks_$query';
    final cached = _getCached<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.searchTracks(query, limit: limit));
      if (data is Map<String, dynamic>) {
        final List items = data['data'] ?? [];
        final all = items.map((item) => Track.fromJson(item)).toList();
        final filtered = all.where((t) => t.rank == null || t.rank! >= _minTrackRank).toList();
        final tracks = filtered.isNotEmpty ? filtered : all;
        _setCache(cacheKey, tracks, isSearch: true);
        return tracks;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] searchTracks error: $e');
    }
    return [];
  }

  // --- Legacy single-endpoint search (kept for compatibility) ---

  Future<Map<String, dynamic>> searchAll(String query) => search(query);

  // --- Entity fetchers ---

  Future<List<Track>> getChartTracks() async {
    const cacheKey = 'chart_tracks';
    final cached = _getCached<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.chartTracks);
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final tracks = list.map((item) => Track.fromJson(item)).toList();
        _setCache(cacheKey, tracks);
        return tracks;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] getChartTracks error: $e');
    }
    return [];
  }

  Future<List<Artist>> getChartArtists() async {
    const cacheKey = 'chart_artists';
    final cached = _getCached<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(ApiEndpoints.chartArtists);
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final artists = list.map((item) => Artist.fromJson(item)).toList();
        _setCache(cacheKey, artists);
        return artists;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] getChartArtists error: $e');
    }
    return [];
  }

  Future<List<Artist>> getFeaturedArtists() async {
    const cacheKey = 'featured_artists';
    final cached = _getCached<List<Artist>>(cacheKey);
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

  Future<List<Artist>> getArtists(List<String> ids) async {
    final futures = ids.map((id) => getArtist(id));
    final results = await Future.wait(futures);
    return results.whereType<Artist>().toList();
  }

  Future<Artist?> getArtist(String id) async {
    final cacheKey = 'artist_$id';
    final cached = _getCached<Artist>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.artist(id));
        if (data is Map<String, dynamic>) {
          final artist = Artist.fromJson(data);
          _setCache(cacheKey, artist);
          return artist;
        }
      } catch (e) {
        debugPrint('[DeezerAPI] getArtist($id) error: $e');
      }
      return null;
    });
  }

  Future<List<Track>> getArtistTopTracks(String artistId,
      {int limit = 10}) async {
    final cacheKey = 'artist_top_${artistId}_$limit';
    final cached = _getCached<List<Track>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data =
          await _fetchJson(ApiEndpoints.artistTopTracks(artistId, limit: limit));
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final tracks = list.map((item) => Track.fromJson(item)).toList();
        _setCache(cacheKey, tracks);
        return tracks;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] getArtistTopTracks($artistId) error: $e');
    }
    return [];
  }

  Future<List<Album>> getArtistAlbums(String artistId,
      {int limit = 250}) async {
    final cacheKey = 'artist_albums_$artistId';
    final cached = _getCached<List<Album>>(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _fetchJson(
          ApiEndpoints.artistAlbums(artistId, limit: limit));
      if (data is Map<String, dynamic>) {
        final List list = data['data'] ?? [];
        final albums = list.map((item) => Album.fromJson(item)).toList();
        _setCache(cacheKey, albums);
        return albums;
      }
    } catch (e) {
      debugPrint('[DeezerAPI] getArtistAlbums($artistId) error: $e');
    }
    return [];
  }

  Future<Album?> getAlbum(String albumId) async {
    final cacheKey = 'album_$albumId';
    final cached = _getCached<Album>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.album(albumId));
        if (data is Map<String, dynamic>) {
          final album = Album.fromJson(data);
          _setCache(cacheKey, album);
          return album;
        }
      } catch (e) {
        debugPrint('[DeezerAPI] getAlbum($albumId) error: $e');
      }
      return null;
    });
  }

  Future<Track?> getTrack(String trackId) async {
    final cacheKey = 'track_$trackId';
    final cached = _getCached<Track>(cacheKey);
    if (cached != null) return cached;

    return _deduped(cacheKey, () async {
      try {
        final data = await _fetchJson(ApiEndpoints.track(trackId));
        if (data is Map<String, dynamic>) {
          final track = Track.fromJson(data);
          _setCache(cacheKey, track);
          return track;
        }
      } catch (e) {
        debugPrint('[DeezerAPI] getTrack($trackId) error: $e');
      }
      return null;
    });
  }

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

  void clearCache() => _cache.clear();
}
