import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/lyrics_search_result.dart';
import '../../domain/entities/synced_lyrics.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  // lrclib asks clients to identify themselves.
  static const Map<String, String> _headers = {
    'User-Agent': 'TsukiTunes/1.0 (https://github.com/nicarcamomw/tsuki_tunes_mobile)',
  };

  /// Songs whose lyrics are kept in memory; the oldest drop out, so a long
  /// session doesn't hold every song's lyrics.
  static const int _maxCached = 150;

  // Insertion-ordered: the first key is the least recently used.
  final LinkedHashMap<String, SyncedLyrics?> _cache = LinkedHashMap();
  final Map<String, Future<SyncedLyrics?>> _inFlight = {};

  static String _cleanString(String text) {
    return text
        .replaceAll(RegExp(r'\(.*?(remaster|deluxe|version|feat|ft\.).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'- .*?(Remaster|Deluxe|Version).*', caseSensitive: false), '')
        .trim();
  }

  Future<SyncedLyrics?> getLyrics(String title, String artistName) async {
    final cleanTitle = _cleanString(title);
    final cleanArtist = _cleanString(artistName);
    final key = '${cleanTitle.toLowerCase()}__${cleanArtist.toLowerCase()}';

    if (_cache.containsKey(key)) {
      // Touch: move to the most recently used end.
      final hit = _cache.remove(key);
      _cache[key] = hit;
      return hit;
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key];
    }

    final future = _fetchLyrics(cleanTitle, cleanArtist, key);
    _inFlight[key] = future;
    return future;
  }

  void _remember(String key, SyncedLyrics? lyrics) {
    _cache.remove(key);
    _cache[key] = lyrics;
    while (_cache.length > _maxCached) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<SyncedLyrics?> _fetchLyrics(
      String title, String artistName, String cacheKey) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'track_name': title,
        'artist_name': artistName,
      });

      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          final result = _fromFields(
            synced: data['syncedLyrics'] as String?,
            plain: data['plainLyrics'] as String?,
            instrumental: data['instrumental'] == true,
          );
          _remember(cacheKey, result);
          return result;
        }
      } else if (response.statusCode == 404) {
        // The exact lookup misses on small title/artist differences; a
        // search by both fields often finds the song anyway.
        final found = await _searchBestMatch(title, artistName);
        // Cache misses too, so the same song isn't looked up again.
        _remember(cacheKey, found);
        return found;
      }
    } catch (e) {
      debugPrint('[LyricsService] Error fetching lyrics for "$title": $e');
    } finally {
      unawaited(_inFlight.remove(cacheKey));
    }
    return null;
  }

  static SyncedLyrics _fromFields({String? synced, String? plain, required bool instrumental}) {
    if (synced != null && synced.trim().isNotEmpty) {
      return SyncedLyrics.fromLrc(synced);
    }
    if (plain != null && plain.trim().isNotEmpty) {
      return SyncedLyrics(
        isSynced: false,
        isInstrumental: instrumental,
        plainLyrics: plain.trim(),
      );
    }
    if (instrumental) return const SyncedLyrics(isInstrumental: true);
    return SyncedLyrics.empty;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  /// Best search hit for this song: same artist (loosely compared), synced
  /// lyrics preferred over plain ones. Null when nothing fits.
  Future<SyncedLyrics?> _searchBestMatch(String title, String artistName) async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': title,
      'artist_name': artistName,
    });
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    if (data is! List) return null;

    final artistKey = _norm(artistName.split(',').first);
    final titleKey = _norm(title);
    LyricsSearchResult? plainHit;
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final r = LyricsSearchResult.fromJson(item);
      final sameArtist = artistKey.isNotEmpty &&
          (_norm(r.artistName).contains(artistKey) || artistKey.contains(_norm(r.artistName)));
      final sameTitle = titleKey.isNotEmpty && _norm(r.trackName).contains(titleKey);
      if (!sameArtist || !sameTitle) continue;
      if ((r.syncedLyrics ?? '').trim().isNotEmpty) {
        return _fromFields(synced: r.syncedLyrics, plain: r.plainLyrics, instrumental: r.instrumental);
      }
      plainHit ??= r;
    }
    final hit = plainHit;
    if (hit == null) return null;
    return _fromFields(synced: hit.syncedLyrics, plain: hit.plainLyrics, instrumental: hit.instrumental);
  }

  Future<List<LyricsSearchResult>> searchByLyrics(String query) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => LyricsSearchResult.fromJson(e))
              .where((r) => !r.instrumental && r.trackName.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] Lyrics search error: $e');
      rethrow;
    }
    return [];
  }

  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  @visibleForTesting
  int get cachedCount => _cache.length;
}
