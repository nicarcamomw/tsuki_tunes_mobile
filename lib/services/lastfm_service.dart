import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LastFmSimilarTrack {
  final String artist;
  final String title;
  final double match;
  const LastFmSimilarTrack(this.artist, this.title, this.match);
}

class LastFmService {
  static const String _apiKey = String.fromEnvironment('LASTFM_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Songs Last.fm listeners play alongside this one, best match first.
  static Future<List<LastFmSimilarTrack>> getSimilarTracks(
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
            LastFmSimilarTrack(
              t['artist']['name'].toString(),
              t['name'].toString(),
              double.tryParse('${t['match']}') ?? 0,
            ),
      ];
    } catch (e) {
      debugPrint('LastFM getSimilarTracks error for $artist - $title: $e');
      return [];
    }
  }

  static Future<List<String>> getArtistTags(String artistName) async {
    try {
      final uri = Uri.parse(
        'https://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=${Uri.encodeComponent(artistName)}&api_key=$_apiKey&format=json&lang=es',
      );
      final response = await http.get(uri);
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
      debugPrint('Error fetching LastFM artist tags for $artistName: $e');
    }
    return [];
  }
}
