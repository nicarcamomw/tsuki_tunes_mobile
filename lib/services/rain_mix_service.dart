import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'deezer_api_service.dart';

class RainMixService {
  static const _cacheKey = 'tsuki_rain_mix_cache';
  static const _cacheTimeKey = 'tsuki_rain_mix_cache_time';
  static const _cacheTtlHours = 24;

  static const _queries = [
    'rain sounds sleep',
    'rain ambient relaxing',
    'rainfall sleep',
    'lluvia relajante dormir',
    'rain lofi sleep',
    'thunderstorm ambient',
  ];

  static final RainMixService _instance = RainMixService._();
  factory RainMixService() => _instance;
  RainMixService._();

  final _deezer = DeezerApiService();
  List<Track>? _memoryCache;

  Future<List<Track>> getTracks({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache!;
    }

    if (!forceRefresh) {
      final cached = await _loadFromDisk();
      if (cached != null && cached.isNotEmpty) {
        _memoryCache = cached;
        return cached;
      }
    }

    final tracks = await _fetchFresh();
    if (tracks.isNotEmpty) {
      _memoryCache = tracks;
      await _saveToDisk(tracks);
    }
    return tracks;
  }

  Future<List<Track>> _fetchFresh() async {
    final allTracks = <Track>[];
    final seen = <String>{};

    for (final query in _queries) {
      try {
        final results = await _deezer.searchTracks(query, limit: 15);
        for (final t in results) {
          if (t.previewUrl.isNotEmpty && seen.add(t.id)) {
            allTracks.add(t);
          }
        }
      } catch (_) {}
      if (allTracks.length >= 40) break;
    }

    allTracks.shuffle(Random());
    return allTracks.take(30).toList();
  }

  Future<List<Track>?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeMs = prefs.getInt(_cacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timeMs;
      if (age > _cacheTtlHours * 3600 * 1000) return null;

      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final List decoded = json.decode(raw);
      return decoded
          .map((item) => Track.fromStorage(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToDisk(List<Track> tracks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = tracks.map((t) => t.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(list));
      await prefs.setInt(
          _cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
