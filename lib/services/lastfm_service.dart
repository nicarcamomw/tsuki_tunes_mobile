import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LastFmService {
  static const String _apiKey = '20ab04496a59664c5fb0dbd7405c69dc';

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
