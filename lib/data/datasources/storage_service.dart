import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../contracts/storage_contract.dart';
import '../local/library_store.dart';
import '../../core/logger.dart';


final _log = Log.named('Storage');

class StorageService implements StorageContract {
  /// [localStore] keeps the library (listened songs, playlists, followed
  /// artists) in SQLite. Without it (web, tests) they stay in JSON files and
  /// SharedPreferences, as before.
  StorageService({LibraryStore? localStore}) : _local = localStore;

  final LibraryStore? _local;

  static const String _favTracksKey = 'tsuki_favorite_tracks';
  static const String _recentTracksKey = 'tsuki_recent_tracks';
  static const String _favArtistsKey = 'tsuki_favorite_artists';
  static const String _artistVisitsKey = 'tsuki_artist_visits';
  static const String _albumTrackCountsKey = 'tsuki_album_track_counts';
  // v2: v1 entries could hold wrong-song matches (artist-only fallback).
  static const String _spotifyUriCacheKey = 'tsuki_spotify_uri_cache_v2';
  static const String _legacySpotifyUriCacheKey = 'tsuki_spotify_uri_cache';

  @override
  Future<List<Track>> getFavoriteTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_favTracksKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List decoded = json.decode(raw);
      return decoded
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
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
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
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
          .map((item) => Artist.fromJson(Map<String, dynamic>.from(item)))
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

  // --- Spotify Resolved URI Cache (deezer_id -> spotify_uri) ---

  @override
  Future<Map<String, String>> getSpotifyUriCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_legacySpotifyUriCacheKey)) {
      await prefs.remove(_legacySpotifyUriCacheKey);
    }
    final String? raw = prefs.getString(_spotifyUriCacheKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final Map decoded = json.decode(raw);
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveSpotifyUriCache(Map<String, String> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spotifyUriCacheKey, json.encode(cache));
  }

  // --- User Cached Listened Tracks (Instant Cold Start & Offline Reliability) ---

  static String _cachedTracksKey(String uid) => 'tsuki_cached_tracks_$uid';
  static String _lastFullSyncKey(String uid) => 'tsuki_listened_full_sync_$uid';

  @override
  Future<DateTime?> getLastListenedFullSync(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastFullSyncKey(uid));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> saveLastListenedFullSync(String uid, DateTime time) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFullSyncKey(uid), time.millisecondsSinceEpoch);
  }

  // The whole listening library: thousands of tracks, megabytes of JSON.
  // It lives in its own file, not in SharedPreferences (which Android reads
  // whole at every launch), and is encoded/decoded off the UI thread when
  // big. Where files aren't available (web) it stays in SharedPreferences.

  // Lists longer than this are (de)serialized in a background isolate.
  static const int _isolateThreshold = 300;
  // Writes run one after another, so an older list never lands last.
  static Future<void> _listenedWrites = Future.value();

  static Future<File?> _listenedFile(String uid) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final safe = uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      return File('${dir.path}/listened_tracks_$safe.json');
    } catch (_) {
      return null; // no path provider (tests): fall back to prefs
    }
  }

  static List<Map<String, dynamic>> _decodeTracks(String raw) {
    final List decoded = json.decode(raw);
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static String _encodeTracks(List<Map<String, dynamic>> tracks) => json.encode(tracks);

  @override
  Future<List<Map<String, dynamic>>> getCachedListenedTracks(String uid) async {
    if (uid.isEmpty) return [];
    final local = _local;
    if (local == null) return _legacyListened(uid);
    try {
      if (!await local.hasListened(uid)) await _moveListenedToDatabase(local, uid);
      return await local.loadListened(uid);
    } catch (e) {
      _log.severe('listened songs from the database failed: $e');
      return _legacyListened(uid);
    }
  }

  /// One-time move of the old JSON library (file, or SharedPreferences
  /// before that) into the database. The old copy is deleted only once the
  /// rows are written; if anything fails it stays, and is tried again.
  Future<void> _moveListenedToDatabase(LibraryStore local, String uid) async {
    final legacy = await _legacyListened(uid);
    if (legacy.isEmpty) return;
    await local.saveListened(uid, legacy);
    try {
      final file = await _listenedFile(uid);
      if (file != null && await file.exists()) await file.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedTracksKey(uid));
    } catch (_) {}
  }

  /// The library as the app kept it before the database.
  Future<List<Map<String, dynamic>>> _legacyListened(String uid) async {
    // A save may still be encoding in the background: read what it writes.
    await _listenedWrites;
    try {
      final file = await _listenedFile(uid);
      if (file != null && await file.exists()) {
        final raw = await file.readAsString();
        if (raw.isEmpty) return [];
        return raw.length > 64 * 1024
            ? await compute(_decodeTracks, raw)
            : _decodeTracks(raw);
      }

      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_cachedTracksKey(uid));
      if (raw == null || raw.isEmpty) return [];
      final tracks = raw.length > 64 * 1024
          ? await compute(_decodeTracks, raw)
          : _decodeTracks(raw);
      if (file != null) {
        // One-time move out of SharedPreferences.
        await _writeListened(file, raw);
        await prefs.remove(_cachedTracksKey(uid));
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveCachedListenedTracks(
      String uid, List<Map<String, dynamic>> tracks) async {
    if (uid.isEmpty) return;
    final local = _local;
    if (local != null) {
      try {
        // Only the songs that changed are written.
        return await local.saveListened(uid, tracks);
      } catch (e) {
        _log.severe('listened songs to the database failed: $e');
      }
    }
    return _saveLegacyListened(uid, tracks);
  }

  Future<void> _saveLegacyListened(String uid, List<Map<String, dynamic>> tracks) {
    final write = _listenedWrites.then((_) async {
      try {
        final raw = tracks.length > _isolateThreshold
            ? await compute(_encodeTracks, tracks)
            : _encodeTracks(tracks);
        final file = await _listenedFile(uid);
        if (file != null) {
          await _writeListened(file, raw);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cachedTracksKey(uid), raw);
        }
      } catch (e) {
        _log.severe('listened tracks save failed: $e');
      }
    });
    _listenedWrites = write;
    return write;
  }

  /// Writes to a temp file and renames it over the old one, so a crash
  /// mid-write never leaves a truncated library behind.
  static Future<void> _writeListened(File file, String raw) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(raw, flush: true);
    await tmp.rename(file.path);
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

  Future<bool> hasExplicitLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_languageKey);
  }

  // --- Crossfade Persistence ---
  static const String _crossfadeKey = 'tsuki_crossfade_seconds';

  @override
  Future<int> getCrossfadeSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_crossfadeKey) ?? 3;
  }

  @override
  Future<void> saveCrossfadeSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_crossfadeKey, seconds);
  }

  // --- Playback settings ---
  static const String _autoMarkKey = 'tsuki_auto_mark_listened';
  static const String _precacheWifiOnlyKey = 'tsuki_precache_wifi_only';

  @override
  Future<bool> getAutoMarkListened() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoMarkKey) ?? false;
  }

  @override
  Future<void> saveAutoMarkListened(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoMarkKey, enabled);
  }

  @override
  Future<bool> getPrecacheWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_precacheWifiOnlyKey) ?? false;
  }

  @override
  Future<void> savePrecacheWifiOnly(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_precacheWifiOnlyKey, enabled);
  }

  // --- Cached Playlists (per-user) ---

  static String _cachedPlaylistsKey(String uid) => 'tsuki_cached_playlists_$uid';

  @override
  Future<List<Map<String, dynamic>>> getCachedPlaylists(String uid) =>
      _fromDatabase(uid, _cachedPlaylistsKey(uid), (l) => l.loadPlaylists(uid), (l, rows) => l.savePlaylists(uid, rows));


  @override
  Future<void> saveCachedPlaylists(String uid, List<Map<String, dynamic>> playlists) =>
      _toDatabase(uid, _cachedPlaylistsKey(uid), playlists, (l) => l.savePlaylists(uid, playlists));


  // --- Cached Followed Artists (per-user) ---

  /// Removes all that this phone keeps for the account [uid] (deleted):
  /// its library in the database, copies left in SharedPreferences and the
  /// listened-songs file.
  Future<void> clearAccountData(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _local?.clearAccount(uid);
    } catch (e) {
      _log.severe('clearing the account in the database failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.endsWith('_$uid')).toList()) {
      await prefs.remove(key);
    }
    try {
      final file = await _listenedFile(uid);
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      _log.warning('removing the listened-songs file failed: $e');
    }
  }

  Future<void> clearCachedPlaylists(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _local?.clearPlaylists(uid);
    } catch (e) {
      _log.severe('clearing playlists in the database failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedPlaylistsKey(uid));
  }


  static String _cachedFollowedArtistsKey(String uid) => 'tsuki_cached_followed_artists_$uid';

  @override
  Future<List<Map<String, dynamic>>> getCachedFollowedArtists(String uid) => _fromDatabase(
      uid, _cachedFollowedArtistsKey(uid), (l) => l.loadFollowed(uid), (l, rows) => l.saveFollowed(uid, rows));


  @override
  Future<void> saveCachedFollowedArtists(String uid, List<Map<String, dynamic>> artists) =>
      _toDatabase(uid, _cachedFollowedArtistsKey(uid), artists, (l) => l.saveFollowed(uid, artists));

  /// Reads a list kept in the database. The first time it's empty there,
  /// a copy left in SharedPreferences (under [legacyKey]) is moved in and
  /// then removed; if the database fails, that copy is what's read.
  Future<List<Map<String, dynamic>>> _fromDatabase(
    String uid,
    String legacyKey,
    Future<List<Map<String, dynamic>>> Function(LibraryStore local) load,
    Future<void> Function(LibraryStore local, List<Map<String, dynamic>> rows) save,
  ) async {
    if (uid.isEmpty) return [];
    final local = _local;
    if (local == null) return _legacyList(legacyKey);
    try {
      final rows = await load(local);
      if (rows.isNotEmpty) return rows;
      final legacy = await _legacyList(legacyKey);
      if (legacy.isEmpty) return rows;
      await save(local, legacy);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(legacyKey);
      return legacy;
    } catch (e) {
      _log.severe('$legacyKey from the database failed: $e');
      return _legacyList(legacyKey);
    }
  }

  /// Saves a list to the database (only the rows that changed), or to
  /// SharedPreferences under [legacyKey] without one or if it fails.
  Future<void> _toDatabase(
    String uid,
    String legacyKey,
    List<Map<String, dynamic>> rows,
    Future<void> Function(LibraryStore local) save,
  ) async {
    if (uid.isEmpty) return;
    final local = _local;
    if (local != null) {
      try {
        return await save(local);
      } catch (e) {
        _log.severe('$legacyKey to the database failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(legacyKey, json.encode(rows));
  }

  Future<List<Map<String, dynamic>>> _legacyList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = json.decode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }


  // --- Birthday ---
  static const String _birthdayKey = 'tsuki_birthday';

  @override
  Future<String?> getBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_birthdayKey);
  }

  @override
  Future<void> saveBirthday(String? birthday) async {
    final prefs = await SharedPreferences.getInstance();
    if (birthday == null) {
      await prefs.remove(_birthdayKey);
    } else {
      await prefs.setString(_birthdayKey, birthday);
    }
  }

  // --- Playback State Persistence ---
  static const String _playbackStateKey = 'tsuki_playback_state';

  @override
  Future<Map<String, dynamic>?> getPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_playbackStateKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePlaybackState(List<Track>? queue,
      [int? currentIndex,
      int? positionMs,
      bool? wasPlaying,
      Map<String, dynamic>? radio]) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue == null || queue.isEmpty) {
      await prefs.remove(_playbackStateKey);
    } else {
      final state = {
        'queue': queue.map((t) => t.toJson()).toList(),
        'currentIndex': currentIndex ?? 0,
        'position': positionMs ?? 0,
        'wasPlaying': wasPlaying ?? false,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        // Same snapshot as the queue, so the radio always matches it.
        if (radio != null) 'radio': radio,
      };
      await prefs.setString(_playbackStateKey, json.encode(state));
    }
  }
}
