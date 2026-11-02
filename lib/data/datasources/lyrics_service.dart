import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/lyrics_search_result.dart';
import '../../domain/entities/synced_lyrics.dart';
import '../../domain/logic/artist_names.dart';
import '../../core/logger.dart';


final _log = Log.named('LyricsService');

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

  /// Lyrics for a song: null when lrclib has none. Throws when lrclib
  /// couldn't be reached, so a network hiccup isn't remembered as "no
  /// lyrics" and the caller can try again.
  Future<SyncedLyrics?> getLyrics(String title, String artistName) async {
    final cleanTitle = _cleanString(title);
    // A collab's joined name ("A, B") rarely matches lrclib exactly; the
    // main artist does.
    final cleanArtist = _cleanString(ArtistNames.primary(artistName));
    final key = '${cleanTitle.toLowerCase()}__${cleanArtist.toLowerCase()}';

    if (_cache.containsKey(key)) {
      // Touch: move to the most recently used end.
      final hit = _cache.remove(key);
      _cache[key] = hit;
      return hit;
    }

    return _inFlight[key] ??= _fetchLyrics(cleanTitle, cleanArtist, key);
  }

  /// Loads a song's lyrics ahead of time (the playing and the next song),
  /// so they are there when the player opens. Failures are ignored.
  void prefetch(String title, String artistName) {
    unawaited(getLyrics(title, artistName).then((_) {}, onError: (_) {}));
  }

  void _remember(String key, SyncedLyrics? lyrics) {
    _cache.remove(key);
    _cache[key] = lyrics;
    while (_cache.length > _maxCached) {
      _cache.remove(_cache.keys.first);
    }
  }

  static const Duration _timeout = Duration(seconds: 10);

  /// The exact lookup and the search run side by side: the exact one wins
  /// when it has lyrics, the search covers small title/artist differences.
  /// Waiting for one before starting the other doubled the wait.
  Future<SyncedLyrics?> _fetchLyrics(
      String title, String artistName, String cacheKey) async {
    try {
      final exact = _exactLookup(title, artistName).then<Object?>((v) => v, onError: (Object e) => e);
      final search =
          _searchBestMatch(title, artistName).then<Object?>((v) => v, onError: (Object e) => e);

      final got = await exact;
      if (got is SyncedLyrics && got != SyncedLyrics.empty) {
        _remember(cacheKey, got);
        return got;
      }
      final found = await search;
      if (found is SyncedLyrics) {
        _remember(cacheKey, found);
        return found;
      }
      final gotAnswered = got == null || got is SyncedLyrics;
      if (gotAnswered && found == null) {
        // Both answered and neither has lyrics: remember the miss.
        final miss = got as SyncedLyrics?;
        _remember(cacheKey, miss);
        return miss;
      }
      final error = gotAnswered ? found! : got;
      _log.severe('Error fetching lyrics for "$title": $error');
      throw error;
    } finally {
      unawaited(_inFlight.remove(cacheKey));
    }
  }

  /// lrclib's exact lookup: null when it doesn't know the song.
  Future<SyncedLyrics?> _exactLookup(String title, String artistName) async {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': title,
      'artist_name': artistName,
    });
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('lrclib get ${response.statusCode}', uri);
    }
    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) return null;
    return _fromFields(
      synced: data['syncedLyrics'] as String?,
      plain: data['plainLyrics'] as String?,
      instrumental: data['instrumental'] == true,
    );
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
    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('lrclib search ${response.statusCode}', uri);
    }
    final data = json.decode(response.body);
    if (data is! List) return null;

    final artistKey = _norm(ArtistNames.primary(artistName));
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
      _log.severe('Lyrics search error: $e');
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
