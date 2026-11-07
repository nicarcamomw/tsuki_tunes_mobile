import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logger.dart';
import '../../domain/entities/similar_track.dart';


final _log = Log.named('LastFM');

class LastFmService {
  static const String _apiKey = String.fromEnvironment('LASTFM_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Songs Last.fm listeners play alongside this one, best match first.
  static Future<List<SimilarTrack>> getSimilarTracks(
    String artist,
    String title, {
    int limit = 60,
  }) async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.https('ws.audioscrobbler.com', '/2.0/', {
        'method': 'track.getsimilar',
        'artist': artist,
        'track': title,
        'autocorrect': '1',
        'limit': '$limit',
        'api_key': _apiKey,
        'format': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final similar = data is Map ? data['similartracks'] : null;
      final list = similar is Map ? similar['track'] : null;
      if (list is! List) return [];
      return [
        for (final t in list)
          if (t is Map &&
              t['name'] != null &&
              t['artist'] is Map &&
              t['artist']['name'] != null)
            SimilarTrack(
              t['artist']['name'].toString(),
              t['name'].toString(),
              double.tryParse('${t['match']}') ?? 0,
            ),
      ];
    } catch (e) {
      _log.severe('LastFM getSimilarTracks error for $artist - $title: $e');
      return [];
    }
  }

  static Future<List<String>> getArtistTags(String artistName) async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.https('ws.audioscrobbler.com', '/2.0/', {
        'method': 'artist.getinfo',
        'artist': artistName,
        'api_key': _apiKey,
        'format': 'json',
        'lang': 'es',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagData = data['artist']?['tags']?['tag'];
        if (tagData is List) {
          return tagData
              .map<String>((t) => t['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (tagData is Map && tagData['name'] != null) {
          return [tagData['name'].toString()];
        }
      }
    } catch (e) {
      _log.severe('Error fetching LastFM artist tags for $artistName: $e');
    }
    return [];
  }

  /// Artist names Last.fm finds for [query], best first. Its search forgives
  /// typos, so it feeds "did you mean" when Deezer finds nothing.
  static Future<List<String>> searchArtistNames(String query,
      {int limit = 5}) async {
    if (!isConfigured || query.trim().isEmpty) return [];
    try {
      final uri = Uri.https('ws.audioscrobbler.com', '/2.0/', {
        'method': 'artist.search',
        'artist': query.trim(),
        'limit': '$limit',
        'api_key': _apiKey,
        'format': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final results = data is Map ? data['results'] : null;
      final found = results is Map ? results['artistmatches'] : null;
      final matches = found is Map ? found['artist'] : null;
      final list = matches is List ? matches : (matches is Map ? [matches] : const []);
      return [
        for (final a in list)
          if (a is Map && (a['name']?.toString().trim().isNotEmpty ?? false))
            a['name'].toString().trim(),
      ];
    } catch (e) {
      _log.severe('LastFM artist.search error for $query: $e');
      return [];
    }
  }
}
