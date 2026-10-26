import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyrics_search_result.dart';
import '../models/synced_lyrics.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Map<String, SyncedLyrics?> _cache = {};
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
      return _cache[key];
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key];
    }

    final future = _fetchLyrics(cleanTitle, cleanArtist, key);
    _inFlight[key] = future;
    return future;
  }

  Future<SyncedLyrics?> _fetchLyrics(
      String title, String artistName, String cacheKey) async {
    try {
      final uri = Uri.parse(
          'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artistName)}');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          final isInstrumental = data['instrumental'] == true;
          final syncedText = data['syncedLyrics'] as String?;
          final plainText = data['plainLyrics'] as String?;

          SyncedLyrics result;
          if (syncedText != null && syncedText.trim().isNotEmpty) {
            result = SyncedLyrics.fromLrc(syncedText);
          } else if (plainText != null && plainText.trim().isNotEmpty) {
            result = SyncedLyrics(
              isSynced: false,
              isInstrumental: isInstrumental,
              plainLyrics: plainText.trim(),
            );
          } else if (isInstrumental) {
            result = const SyncedLyrics(isInstrumental: true);
          } else {
            result = SyncedLyrics.empty;
          }

          _cache[cacheKey] = result;
          return result;
        }
      } else if (response.statusCode == 404) {
        // Track not found in database - cache null to avoid re-querying repeatedly
        _cache[cacheKey] = null;
        return null;
      }
    } catch (e) {
      debugPrint('[LyricsService] Error fetching lyrics for "$title": $e');
    } finally {
      unawaited(_inFlight.remove(cacheKey));
    }
    return null;
  }

  Future<List<LyricsSearchResult>> searchByLyrics(String query) async {
    try {
      final uri = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

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
}
