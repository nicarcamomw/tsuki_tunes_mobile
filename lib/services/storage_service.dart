import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/artist.dart';
import 'contracts/storage_contract.dart';

class StorageService implements StorageContract {
  static const String _favTracksKey = 'tsuki_favorite_tracks';
  static const String _recentTracksKey = 'tsuki_recent_tracks';
  static const String _favArtistsKey = 'tsuki_favorite_artists';
  static const String _artistVisitsKey = 'tsuki_artist_visits';
  static const String _albumTrackCountsKey = 'tsuki_album_track_counts';

  @override
  Future<List<Track>> getFavoriteTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_favTracksKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List decoded = json.decode(raw);
      return decoded
          .map((item) => Track.fromStorage(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveFavoriteTracks(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tracks.map((t) => t.toJson()).toList();
    await prefs.setString(_favTracksKey, json.encode(list));
  }

  @override
  Future<List<Track>> getRecentTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_recentTracksKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List decoded = json.decode(raw);
      return decoded
          .map((item) => Track.fromStorage(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveRecentTracks(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tracks.map((t) => t.toJson()).toList();
    await prefs.setString(_recentTracksKey, json.encode(list));
  }

  @override
  Future<List<Artist>> getFavoriteArtists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_favArtistsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List decoded = json.decode(raw);
      return decoded
          .map((item) => Artist.fromStorage(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveFavoriteArtists(List<Artist> artists) async {
    final prefs = await SharedPreferences.getInstance();
    final list = artists.map((a) => a.toJson()).toList();
    await prefs.setString(_favArtistsKey, json.encode(list));
  }

  // --- Artist visits tracking (for top artists calculation) ---

  @override
  Future<Map<String, int>> getArtistVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_artistVisitsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final Map decoded = json.decode(raw);
      return decoded.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveArtistVisits(Map<String, int> visits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_artistVisitsKey, json.encode(visits));
  }

  // --- Album Track Counts Cache ---

  @override
  Future<Map<String, int>> getAlbumTrackCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_albumTrackCountsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final Map decoded = json.decode(raw);
      return decoded.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveAlbumTrackCounts(Map<String, int> counts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_albumTrackCountsKey, json.encode(counts));
  }

  // --- User Cached Listened Tracks (Instant Cold Start & Offline Reliability) ---

  static String _cachedTracksKey(String uid) => 'tsuki_cached_tracks_$uid';

  @override
  Future<List<Map<String, dynamic>>> getCachedListenedTracks(String uid) async {
    if (uid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_cachedTracksKey(uid));
    if (raw == null || raw.isEmpty) return [];

    try {
      final List decoded = json.decode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveCachedListenedTracks(
      String uid, List<Map<String, dynamic>> tracks) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedTracksKey(uid), json.encode(tracks));
  }

  // --- Onboarding Persistence ---
  static const String _onboardingKey = 'tsuki_has_completed_onboarding';

  @override
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  @override
  Future<void> setCompletedOnboarding(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  // --- Language Persistence ---
  static const String _languageKey = 'tsuki_app_language';

  @override
  Future<String> getAppLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'es';
  }

  @override
  Future<void> saveAppLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }
}
