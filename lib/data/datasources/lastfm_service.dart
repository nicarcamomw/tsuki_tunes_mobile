import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logger.dart';
import '../../domain/entities/similar_track.dart';
import 'backend_proxy.dart';


final _log = Log.named('LastFM');

/// Last.fm, through Tsuki's backend (BackendProxy), which holds the key:
/// the app no longer needs one. A build that still has the key compiled in
/// (LASTFM_API_KEY) calls Last.fm directly when the backend can't be
/// reached, until the proxy is deployed everywhere.
class LastFmService {
  static const String _apiKey = String.fromEnvironment('LASTFM_API_KEY');

  static bool get isConfigured =>
      BackendProxy.instance.isAvailable || _apiKey.isNotEmpty;

  /// Answers to these come from the caller, not the network: not worth
  /// retrying with the key.
  static const _finalStatuses = {400, 401, 429};

  /// Last.fm's JSON for [params] (a method and its parameters), or null.
  static Future<Map<String, dynamic>?> _call(Map<String, String> params,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final res =
        await BackendProxy.instance.get('lastfm', params, timeout: timeout);
    if (res != null) {
      if (res.statusCode == 200) return _decode(res.body);
      if (_finalStatuses.contains(res.statusCode)) {
        _log.warning('backend refused ${params['method']}: ${res.statusCode}');
        return null;
      }
    }
    if (_apiKey.isEmpty) return null;
    // The backend isn't there (not deployed yet, or down): the old way.
    final direct = Uri.https('ws.audioscrobbler.com', '/2.0/',
        {...params, 'api_key': _apiKey, 'format': 'json'});
    final response = await http.get(direct).timeout(timeout);
    return response.statusCode == 200 ? _decode(response.body) : null;
  }

  static Map<String, dynamic>? _decode(String body) {
    final data = jsonDecode(body);
    return data is Map<String, dynamic> ? data : null;
  }

  /// Songs Last.fm listeners play alongside this one, best match first.
  static Future<List<SimilarTrack>> getSimilarTracks(
    String artist,
    String title, {
    int limit = 60,
  }) async {
    if (!isConfigured) return [];
    try {
      final data = await _call({
        'method': 'track.getsimilar',
        'artist': artist,
        'track': title,
        'autocorrect': '1',
        'limit': '$limit',
      });
      final similar = data?['similartracks'];
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
      final data = await _call({
        'method': 'artist.getinfo',
        'artist': artistName,
        'lang': 'es',
      });
      final tagData = data?['artist']?['tags']?['tag'];
      if (tagData is List) {
        return tagData
            .map<String>((t) => t['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (tagData is Map && tagData['name'] != null) {
        return [tagData['name'].toString()];
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
      final data = await _call({
        'method': 'artist.search',
        'artist': query.trim(),
        'limit': '$limit',
      }, timeout: const Duration(seconds: 6));
      final results = data?['results'];
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
