import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_environment.dart';
import '../../core/logger.dart';
import '../../domain/entities/external_library.dart';
import '../../domain/entities/playback_error.dart';
import 'perf_tracker.dart';
import 'storage_service.dart';


final _log = Log.named('SpotifyService');

class SpotifyService {
  // Every Spotify request is bounded: a stalled connection must fail (and
  // let playback fall back) instead of leaving play or login waiting forever.
  static const _apiTimeout = Duration(seconds: 10);
  static const _authTimeout = Duration(seconds: 15);

  // Every request is timed by endpoint in Firebase Performance (PerfTracker).
  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      PerfTracker.instance.request(
          'GET', url, () => http.get(url, headers: headers).timeout(_apiTimeout));

  static Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) =>
      PerfTracker.instance.request('PUT', url,
          () => http.put(url, headers: headers, body: body).timeout(_apiTimeout));

  static Future<http.Response> _post(Uri url,
          {Map<String, String>? headers, Object? body, Duration timeout = _apiTimeout}) =>
      PerfTracker.instance.request('POST', url,
          () => http.post(url, headers: headers, body: body).timeout(timeout));

  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static final _redirectUri = spotifyRedirectUri;
  static const _scopes =
      'streaming user-read-private '
      'user-read-playback-state user-modify-playback-state '
      'user-read-currently-playing user-library-read user-top-read '
      'playlist-read-private playlist-read-collaborative';

  static const _tokenKey = 'spotify_access_token';
  static const _refreshKey = 'spotify_refresh_token';
  static const _expiryKey = 'spotify_token_expiry';
  static const _profileKey = 'spotify_profile';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _profile;
  bool _isPremium = false;
  String? _lastError;
  SpotifyConnectError? _lastErrorKind;
  String? _activeDeviceName;
  Completer<void>? _refreshLock;

  // The phone Spotify last played on: plays and resumes go straight to it,
  // without listing the devices first.
  /// The device the user chose to listen on (Spotify Connect: a PC, a
  /// speaker, a console), while it is around; null plays on this phone.
  String? _preferredDeviceId;
  String? _preferredDeviceName;
  String? get listeningOnName => _preferredDeviceName;

  String? _phoneDeviceId;

  // URI cache: deezer_id / query -> spotify_uri (persisted in SharedPreferences)
  final Map<String, String> _uriCache = {};
  bool _uriCacheLoaded = false;
  static const int _maxUriCacheEntries = 2000;
  Timer? _saveCacheTimer;

  bool get isConnected => _accessToken != null;
  bool get isPremium => _isPremium;
  Map<String, dynamic>? get profile => _profile;
  /// What Spotify or the system said when [connect] last failed, for the logs.
  String? get lastError => _lastError;

  /// Why [connect] last failed; null after a success.
  SpotifyConnectError? get lastErrorKind => _lastErrorKind;

  /// Records why [connect] failed: [kind], and [detail] for the logs. Any
  /// failure whose text says it was cancelled counts as cancelled.
  void _fail(SpotifyConnectError kind, String? detail) {
    _lastError = detail;
    _lastErrorKind = (detail ?? '').toLowerCase().contains('cancel') ? SpotifyConnectError.canceled : kind;
  }

  /// The account signed in, but Spotify refuses this app to it: while the
  /// app is in Spotify's development mode only the few accounts added in
  /// its dashboard may use it (five, since February 2026).
  bool get accessRestricted => _accessRestricted;
  bool _accessRestricted = false;

  /// The last connect failed because this Spotify account isn't on the
  /// app's allow list (development mode).
  bool get isNotRegistered => _lastErrorKind == SpotifyConnectError.notRegistered;
  String? get accessToken => _accessToken;
  String? get activeDeviceName => _activeDeviceName;

  Future<String?> getValidToken() async {
    await _ensureValidToken();
    return _accessToken;
  }
  String? get displayName => _profile?['display_name'];
  String? get profileImage {
    final images = _profile?['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) return first['url'] as String?;
    }
    return null;
  }

  Future<void> loadSavedState() async {
    // Migrate tokens from SharedPreferences to secure storage (one-time)
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null) {
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      final legacyRefresh = prefs.getString(_refreshKey);
      if (legacyRefresh != null) {
        await _secureStorage.write(key: _refreshKey, value: legacyRefresh);
      }
      final legacyExpiry = prefs.getInt(_expiryKey);
      if (legacyExpiry != null) {
        await _secureStorage.write(key: _expiryKey, value: legacyExpiry.toString());
      }
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshKey);
      await prefs.remove(_expiryKey);
    }

    _accessToken = await _secureStorage.read(key: _tokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshKey);
    final expiryStr = await _secureStorage.read(key: _expiryKey);
    if (expiryStr != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
    }
    // Migrate profile from SharedPreferences to secure storage (one-time)
    final legacyProfile = prefs.getString(_profileKey);
    if (legacyProfile != null) {
      await _secureStorage.write(key: _profileKey, value: legacyProfile);
      await prefs.remove(_profileKey);
    }
    final profileJson = await _secureStorage.read(key: _profileKey);
    if (profileJson != null) {
      try {
        _profile = json.decode(profileJson);
        _isPremium = _profile?['product'] == 'premium';
      } catch (_) {}
    }

    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isAfter(_tokenExpiry!)) {
        await _refreshAccessToken();
      }
    }

    await _ensureUriCacheLoaded();
  }

  Future<void> _ensureUriCacheLoaded() async {
    if (_uriCacheLoaded) return;
    try {
      final loaded = await StorageService().getSpotifyUriCache();
      _uriCache.addAll(loaded);
      _uriCacheLoaded = true;
    } catch (e) {
      _log.severe('error loading URI cache: $e');
    }
  }

  String? _getFromCache(String? trackId, String title, String artist) {
    if (trackId != null && trackId.isNotEmpty) {
      final cached = _uriCache.remove(trackId);
      if (cached != null) {
        _uriCache[trackId] = cached; // LRU touch
        return cached;
      }
    }
    final fallbackKey = '${artist.toLowerCase().trim()}:::${title.toLowerCase().trim()}';
    final cachedFallback = _uriCache.remove(fallbackKey);
    if (cachedFallback != null) {
      _uriCache[fallbackKey] = cachedFallback; // LRU touch
      if (trackId != null && trackId.isNotEmpty) {
        _uriCache[trackId] = cachedFallback;
      }
      return cachedFallback;
    }
    return null;
  }

  void _saveToCache(String? trackId, String title, String artist, String uri) {
    if (trackId != null && trackId.isNotEmpty) {
      _uriCache.remove(trackId);
      _uriCache[trackId] = uri;
    }
    final fallbackKey = '${artist.toLowerCase().trim()}:::${title.toLowerCase().trim()}';
    _uriCache.remove(fallbackKey);
    _uriCache[fallbackKey] = uri;

    while (_uriCache.length > _maxUriCacheEntries) {
      _uriCache.remove(_uriCache.keys.first);
    }

    _scheduleSaveCache();
  }

  void _scheduleSaveCache() {
    _saveCacheTimer?.cancel();
    _saveCacheTimer = Timer(const Duration(milliseconds: 500), () {
      StorageService().saveSpotifyUriCache(_uriCache);
    });
  }

  @visibleForTesting
  Map<String, String> get uriCache => _uriCache;

  @visibleForTesting
  set accessTokenForTesting(String token) => _accessToken = token;

  @visibleForTesting
  void populateUriCacheForTesting(Map<String, String> cache) {
    _uriCache.addAll(cache);
    _uriCacheLoaded = true;
  }

  /// Forgets which songs were looked up (they show what was played). Only
  /// for a change of account (logout, account deletion), not on disconnect:
  /// playback just looks each song up again, a little slower the first time.
  Future<void> clearUriCache() async {
    _saveCacheTimer?.cancel();
    _uriCache.clear();
    _uriCacheLoaded = true; // nothing older to load back in
    await StorageService().saveSpotifyUriCache({});
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(96, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '').substring(0, 128);
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<bool> connect() async {
    _lastError = null;
    _lastErrorKind = null;
    _accessRestricted = false;
    try {
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = base64Url.encode(
          List<int>.generate(16, (_) => Random.secure().nextInt(256)));

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'state': state,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: spotifyRedirectScheme,
      );

      final uri = Uri.parse(result);
      if (uri.queryParameters.containsKey('error')) {
        _fail(SpotifyConnectError.server,
            uri.queryParameters['error_description'] ?? uri.queryParameters['error']);
        _log.severe('Spotify auth redirect error: $_lastError');
        return false;
      }

      final returnedState = uri.queryParameters['state'];
      if (returnedState != state) {
        _fail(SpotifyConnectError.stateMismatch, 'oauth_state_mismatch');
        _log.fine('Spotify auth: OAuth state mismatch (CSRF protection)');
        return false;
      }

      final code = uri.queryParameters['code'];
      if (code == null) {
        _fail(SpotifyConnectError.noAuthCode, 'auth_code_not_found');
        return false;
      }

      return await _exchangeCode(code, codeVerifier);
    } catch (e) {
      _log.severe('Spotify connect error: $e');
      final errStr = e.toString();
      if (errStr.contains('CANCELED') || errStr.contains('user_canceled')) {
        _fail(SpotifyConnectError.canceled, 'canceled_by_user');
      } else {
        _fail(SpotifyConnectError.other, 'connect_error: $e');
      }
      return false;
    }
  }

  Future<bool> _exchangeCode(String code, String codeVerifier) async {
    try {
      final response = await _post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
        timeout: _authTimeout,
      );

      if (response.statusCode != 200) {
        _log.severe('Spotify exchange failed (${response.statusCode})');
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          _fail(SpotifyConnectError.server,
              '${data['error_description'] ?? data['error'] ?? 'auth_failed_${response.statusCode}'}');
        } catch (_) {
          _fail(SpotifyConnectError.server, 'server_error_${response.statusCode}');
        }
        return false;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _tokenExpiry =
          DateTime.now().add(Duration(seconds: data['expires_in']));

      await _saveTokens();
      await _fetchProfile();
      if (_accessRestricted) {
        // Signed in, but nothing would work: don't stay half connected.
        _log.warning('Spotify: this account is not allowed to use the app');
        await disconnect();
        _accessRestricted = true;
        _fail(SpotifyConnectError.notRegistered, 'user_not_registered');
        return false;
      }
      return _accessToken != null;
    } catch (e) {
      _log.severe('Spotify exchange error: $e');
      _fail(SpotifyConnectError.network, 'network_error: $e');
      return false;
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) return;

    try {
      final response = await _post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
        timeout: _authTimeout,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: data['expires_in']));
        await _saveTokens();
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        // Permanent invalid grant - token was revoked
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          if (data['error'] == 'invalid_grant') {
            _log.fine('Spotify refresh token invalid_grant: disconnecting');
            await disconnect();
          }
        } catch (_) {}
      } else {
        _log.fine('Spotify refresh transient status: ${response.statusCode}');
      }
    } catch (e) {
      _log.severe('Spotify refresh network error: $e');
      // Do not disconnect on network errors so playback can retry
    }
  }

  Future<void> _ensureValidToken() async {
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      if (_refreshLock != null) {
        await _refreshLock!.future;
        return;
      }
      _refreshLock = Completer<void>();
      try {
        await _refreshAccessToken();
      } finally {
        _refreshLock!.complete();
        _refreshLock = null;
      }
    }
  }

  Future<void> refreshProfile() => _fetchProfile();

  Future<void> _fetchProfile() async {
    if (_accessToken == null) return;

    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        _accessRestricted = false;
        _profile = json.decode(response.body);
        _isPremium = _profile?['product'] == 'premium';
        await _secureStorage.write(key: _profileKey, value: json.encode(_profile));
      } else if (response.statusCode == 403) {
        // "Check settings on developer.spotify.com/dashboard, the user may
        // not be registered": the account isn't one of the app's users.
        _accessRestricted = true;
        _isPremium = false;
      }
    } catch (e) {
      _log.severe('Spotify profile error: $e');
    }
  }

  Future<bool> openSpotifyApp() async {
    final uri = Uri.parse('spotify:');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _log.severe('Error launching Spotify app: $e');
    }
    return false;
  }

  // --- Playback ---

  /// Resolves the Spotify URI for a Deezer track.
  ///
  /// Matching order: local cache → ISRC (exact recording) → title + artist
  /// search. A result is only accepted when both the normalized title and one
  /// of the artists match, so a different song by the same artist is never
  /// played. [isrcResolver] is only called on a cache miss, so callers can
  /// fetch the ISRC lazily (Deezer only returns it from /track/{id}).
  /// The Spotify URI of a track already looked up before, without any
  /// request (null when it wasn't).
  Future<String?> cachedTrackUri(String title, String artist,
      {String? trackId}) async {
    await _ensureUriCacheLoaded();
    return _getFromCache(trackId, title, artist);
  }

  Future<String?> searchTrack(
    String title,
    String artist, {
    String? trackId,
    String? isrc,
    Future<String?> Function()? isrcResolver,
  }) async {
    await _ensureUriCacheLoaded();

    final cachedUri = _getFromCache(trackId, title, artist);
    if (cachedUri != null) {
      _log.fine('Spotify: using locally cached URI for "$title" (${trackId ?? 'no-id'}): $cachedUri');
      return cachedUri;
    }

    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      var resolvedIsrc = isrc;
      if ((resolvedIsrc == null || resolvedIsrc.isEmpty) &&
          isrcResolver != null) {
        resolvedIsrc = await isrcResolver();
      }

      if (resolvedIsrc != null && resolvedIsrc.isNotEmpty) {
        final items = await _searchItems('isrc:$resolvedIsrc', limit: 5);
        if (items != null && items.isNotEmpty) {
          final resolvedUri = items.first['uri'] as String;
          _log.fine('Spotify: ISRC match "${items.first['name']}" ($resolvedIsrc)');
          _saveToCache(trackId, title, artist, resolvedUri);
          return resolvedUri;
        }
      }

      // Try structured query first, then simple query as fallback
      final queries = [
        'track:$title artist:$artist',
        '$title $artist',
      ];

      final wantedTitle = normalizeTitle(title);
      final wantedArtists = artist
          .split(',')
          .map(_normalize)
          .where((a) => a.isNotEmpty)
          .toList();

      for (final query in queries) {
        final items = await _searchItems(query, limit: 10);
        if (items == null || items.isEmpty) continue;

        for (final item in items) {
          final trackName = normalizeTitle(item['name'] as String? ?? '');
          if (trackName != wantedTitle) continue;
          final artists = (item['artists'] as List?)?.whereType<Map>() ?? const <Map>[];
          final artistMatches = artists.any((a) {
            final spotifyArtist = _normalize(a['name'] as String? ?? '');
            return wantedArtists.any((w) =>
                spotifyArtist == w ||
                spotifyArtist.contains(w) ||
                w.contains(spotifyArtist));
          });
          if (artistMatches) {
            final resolvedUri = item['uri'] as String;
            _log.fine('Spotify: title+artist match "${item['name']}"');
            _saveToCache(trackId, title, artist, resolvedUri);
            return resolvedUri;
          }
        }
      }
    } catch (e) {
      _log.severe('Spotify search error: $e');
    }
    _log.fine('Spotify: no reliable match for "$title" by "$artist"');
    return null;
  }

  Future<List<Map<String, dynamic>>?> _searchItems(String query, {required int limit}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/search'
            '?q=${Uri.encodeComponent(query)}&type=track&limit=$limit'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 401 && attempt == 0) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(0);
        await _ensureValidToken();
        if (_accessToken == null) return null;
        continue;
      }
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final tracks = data['tracks'];
      final items = tracks is Map ? tracks['items'] : null;
      return items is List ? items.whereType<Map<String, dynamic>>().toList() : null;
    }
    return null;
  }

  static String _normalize(String s) {
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      buffer.write(accents[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r"[^\p{L}\p{N} ]", unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Strips version decorations so "Song - Remastered 2011" and
  /// "Song (feat. X)" compare equal to "Song".
  @visibleForTesting
  static String normalizeTitle(String title) {
    var t = title.toLowerCase();
    t = t.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ');
    t = t.replaceAll(
        RegExp(r'\s-\s.*(remaster|version|live|edit|mix|mono|stereo|acoustic|demo|deluxe|bonus).*$'),
        '');
    t = t.replaceAll(RegExp(r'\s(feat\.?|ft\.?|featuring)\s.*$'), '');
    return _normalize(t);
  }

  // ── Import ──

  /// Spotify answered that the saved sign-in lacks a permission the app
  /// now asks for (reading playlists): connecting again grants it.
  bool importNeedsReconnect = false;

  Future<Map<String, dynamic>?> _getJson(Uri url) async {
    await _ensureValidToken();
    if (_accessToken == null) return null;
    final res = await _get(url, headers: {'Authorization': 'Bearer $_accessToken'});
    if (res.statusCode == 403 || res.statusCode == 401) {
      importNeedsReconnect = res.statusCode == 403 || importNeedsReconnect;
      return null;
    }
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }

  /// The user's playlists (theirs and the ones they follow), and how many
  /// songs they saved, as the first entry.
  Future<List<ExternalPlaylist>> getImportablePlaylists() async {
    importNeedsReconnect = false;
    final out = <ExternalPlaylist>[];
    final liked = await _getJson(Uri.parse('https://api.spotify.com/v1/me/tracks?limit=1'));
    final likedTotal = liked?['total'];
    if (likedTotal is int && likedTotal > 0) {
      out.add(ExternalPlaylist(id: 'liked', name: 'Liked', total: likedTotal, liked: true));
    }
    Uri? next = Uri.parse('https://api.spotify.com/v1/me/playlists?limit=50');
    var pages = 0;
    while (next != null && pages++ < 10) {
      final page = await _getJson(next);
      if (page == null) break;
      for (final p in (page['items'] as List? ?? const [])) {
        if (p is! Map || p['id'] == null) continue;
        final images = p['images'];
        final tracks = p['tracks'];
        out.add(ExternalPlaylist(
          id: p['id'] as String,
          name: (p['name'] as String?)?.trim().isNotEmpty == true ? p['name'] as String : 'Playlist',
          total: tracks is Map && tracks['total'] is int ? tracks['total'] as int : 0,
          imageUrl: images is List && images.isNotEmpty ? switch (images.first) { final Map m => m['url'] as String?, _ => null } : null,
        ));
      }
      final n = page['next'];
      next = n is String ? Uri.parse(n) : null;
    }
    return out;
  }

  /// The songs of [playlist], up to [limit].
  Future<List<ExternalTrack>> getImportTracks(ExternalPlaylist playlist, {int limit = 1000}) async {
    final out = <ExternalTrack>[];
    Uri? next = playlist.liked
        ? Uri.parse('https://api.spotify.com/v1/me/tracks?limit=50')
        : Uri.parse('https://api.spotify.com/v1/playlists/${playlist.id}/tracks?limit=100'
            '&fields=next,items(track(name,duration_ms,external_ids(isrc),artists(name),type))');
    while (next != null && out.length < limit) {
      final page = await _getJson(next);
      if (page == null) break;
      for (final item in (page['items'] as List? ?? const [])) {
        final t = item is Map ? item['track'] : null;
        if (t is! Map || t['name'] == null) continue;
        if (t['type'] != null && t['type'] != 'track') continue; // podcast episodes
        final ids = t['external_ids'];
        out.add(ExternalTrack(
          title: t['name'] as String,
          artists: [
            for (final a in (t['artists'] as List? ?? const []))
              if (a is Map && a['name'] is String) a['name'] as String,
          ],
          isrc: ids is Map ? ids['isrc'] as String? : null,
          durationMs: t['duration_ms'] is int ? t['duration_ms'] as int : 0,
        ));
      }
      final n = page['next'];
      next = n is String ? Uri.parse(n) : null;
    }
    return out.take(limit).toList();
  }

  Future<String?> getActiveDeviceId() async {
    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me/player/devices'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final devices = (data['devices'] as List?)?.whereType<Map<String, dynamic>>().toList();
        if (devices != null && devices.isNotEmpty) {
          for (final d in devices) {
            _log.fine('Spotify device: ${d['name']} (${d['type']}) active=${d['is_active']}');
          }
          // Prefer smartphone, then active device, then first
          final smartphone = devices.where(
            (d) => d['type'] == 'Smartphone',
          ).toList();
          final chosen = smartphone.isNotEmpty
              ? smartphone.first
              : devices.firstWhere(
                  (d) => d['is_active'] == true,
                  orElse: () => devices.first,
                );
          final deviceId = chosen['id'] as String?;
          _activeDeviceName = chosen['name'] as String?;
          _log.fine('Spotify chosen device: $_activeDeviceName (${chosen['type']})');
          return deviceId;
        }
        _activeDeviceName = null;
        _log.fine('Spotify: no devices found');
      }
    } catch (e) {
      _log.severe('Spotify devices error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    await _ensureValidToken();
    if (_accessToken == null) return [];

    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me/player/devices'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final devices = (data['devices'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
        return devices;
      }
    } catch (e) {
      _log.severe('Spotify getDevices error: $e');
    }
    return [];
  }

  @visibleForTesting
  Future<bool> transferPlayback(String deviceId) async {
    try {
      final response = await _put(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'device_ids': [deviceId],
          'play': false,
        }),
      );
      _log.fine('Spotify transfer: ${response.statusCode}');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _log.severe('Spotify transfer error: $e');
      return false;
    }
  }

  /// Moves Spotify's playback to [deviceId] (Spotify Connect) and keeps it
  /// playing there; Tsuki's next songs follow it. A smartphone means this
  /// phone again. False when Spotify refused.
  Future<bool> listenOn(String deviceId, {required String name, required bool isPhone}) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;
    try {
      final response = await _put(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'device_ids': [deviceId],
          'play': true,
        }),
      );
      final ok = response.statusCode == 204 || response.statusCode == 200;
      _log.fine('Spotify listen on $name: ${response.statusCode}');
      if (ok) {
        _preferredDeviceId = isPhone ? null : deviceId;
        _preferredDeviceName = isPhone ? null : name;
        _phoneDeviceId = deviceId;
        _activeDeviceName = name;
      }
      return ok;
    } catch (e) {
      _log.severe('Spotify listen on error: $e');
      return false;
    }
  }

  Future<String?> ensureActiveDevice() async {
    final devices = await getDevices();
    if (devices.isEmpty) {
      _log.fine('Spotify: no devices available at all');
      return null;
    }

    // A device the user chose stays the target while it's around; once it
    // is gone (turned off), playback comes back to the phone.
    final preferred = _preferredDeviceId;
    if (preferred != null) {
      final found = devices.where((d) => d['id'] == preferred).toList();
      if (found.isNotEmpty) {
        if (found.first['is_active'] != true) {
          await transferPlayback(preferred);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return _phoneDeviceId = preferred;
      }
      _log.fine('Spotify: the chosen device is gone, back to the phone');
      _preferredDeviceId = null;
      _preferredDeviceName = null;
    }

    for (final d in devices) {
      _log.fine('Spotify device: ${d['name']} (${d['type']}) active=${d['is_active']}');
    }

    final smartphones = devices.where((d) => d['type'] == 'Smartphone').toList();

    // If a smartphone is already active, use it
    final activePhone = smartphones.where((d) => d['is_active'] == true).toList();
    if (activePhone.isNotEmpty) {
      _log.fine('Spotify: using active smartphone ${activePhone.first['name']}');
      return _phoneDeviceId = activePhone.first['id'] as String?;
    }

    // If there's a smartphone but not active, transfer to it
    if (smartphones.isNotEmpty) {
      final phoneId = smartphones.first['id'] as String?;
      if (phoneId != null) {
        _log.fine('Spotify: forcing playback to smartphone ${smartphones.first['name']}');
        await transferPlayback(phoneId);
        // The transfer settles asynchronously: a play sent sooner is often
        // dropped. Only on this cold path; warm plays use _phoneDeviceId.
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return _phoneDeviceId = phoneId;
    }

    // No smartphone found — do NOT fall back to other device types (TV,
    // speaker, etc.).  Returning null lets the caller use App Remote which
    // plays on the local phone only.
    _log.fine('Spotify: no Smartphone device found, skipping non-phone devices');
    return null;
  }

  /// Plays [trackUris] in order (or just [trackUri]) on this phone, from
  /// [positionMs] into the first one. Spotify then moves through the list
  /// by itself, even when Tsuki is asleep in the background.
  Future<bool> play({
    String? trackUri,
    List<String>? trackUris,
    String? deviceId,
    int? positionMs,
  }) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      // Ensure we have an active smartphone device — never play on a
      // non-phone (TV, speaker, etc.). The phone of the last play needs no
      // lookup; if it's gone, it's looked up again below.
      final remembered = deviceId == null ? _phoneDeviceId : null;
      final targetDevice = deviceId ?? remembered ?? await ensureActiveDevice();
      if (targetDevice == null) {
        _log.fine('Spotify play: no smartphone device available');
        return false;
      }

      final body = <String, dynamic>{};
      if (trackUris != null && trackUris.isNotEmpty) {
        body['uris'] = trackUris;
      } else if (trackUri != null) {
        body['uris'] = [trackUri];
      }
      if (positionMs != null && positionMs > 0) body['position_ms'] = positionMs;

      final url =
          'https://api.spotify.com/v1/me/player/play?device_id=$targetDevice';
      final response = await _put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      _log.fine('Spotify play: ${response.statusCode} (device=$targetDevice)');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _phoneDeviceId = targetDevice;
        return true;
      }

      if (remembered != null && response.statusCode != 401) {
        // The remembered phone is gone or asleep: look it up again.
        _phoneDeviceId = null;
        return await play(
            trackUri: trackUri, trackUris: trackUris, positionMs: positionMs);
      }

      if (response.statusCode == 401) {
        await _ensureValidToken();
        if (_accessToken == null) return false;
        final retry401 = await _put(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        );
        if (retry401.statusCode == 204 || retry401.statusCode == 200) {
          return true;
        }
      }

      // Play failed — try transfer + retry once
      _log.warning('Spotify play failed, forcing transfer and retry');
      await transferPlayback(targetDevice);
      await Future.delayed(const Duration(milliseconds: 800));

      final retry = await _put(
        Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$targetDevice'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      _log.warning('Spotify play retry: ${retry.statusCode}');
      return retry.statusCode == 204 || retry.statusCode == 200;
    } catch (e) {
      _log.severe('Spotify play error: $e');
      return false;
    }
  }

  Future<bool> pause() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await _put(
        Uri.parse('https://api.spotify.com/v1/me/player/pause'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _log.severe('Spotify pause error: $e');
      return false;
    }
  }

  Future<bool> resume() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      // Resume on the phone of the last play (no device lookup). Never
      // without a device_id: Spotify would resume wherever it was last
      // active, a PC or a speaker included.
      final remembered = _phoneDeviceId;
      if (remembered != null) {
        final response = await _put(
          Uri.parse(
              'https://api.spotify.com/v1/me/player/play?device_id=$remembered'),
          headers: {'Authorization': 'Bearer $_accessToken'},
        );
        _log.fine('Spotify resume response: ${response.statusCode}');
        if (response.statusCode == 204 || response.statusCode == 200) {
          return true;
        }
        _phoneDeviceId = null;
      }

      // Phone unknown or gone: resolve and retry.
      final deviceId = await ensureActiveDevice();
      if (deviceId == null) {
        _log.fine('Spotify resume: no smartphone device');
        return false;
      }
      final retry = await _put(
        Uri.parse(
            'https://api.spotify.com/v1/me/player/play?device_id=$deviceId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      _log.warning('Spotify resume retry: ${retry.statusCode}');
      return retry.statusCode == 204 || retry.statusCode == 200;
    } catch (e) {
      _log.severe('Spotify resume error: $e');
      return false;
    }
  }

  Future<bool> seekTo(int positionMs) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await _put(
        Uri.parse(
            'https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204;
    } catch (e) {
      _log.severe('Spotify seek error: $e');
      return false;
    }
  }

  /// Sets Spotify's repeat mode: 'track', 'context' or 'off'.
  Future<bool> setRepeat(String state) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await _put(
        Uri.parse('https://api.spotify.com/v1/me/player/repeat?state=$state'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _log.severe('Spotify repeat error: $e');
      return false;
    }
  }

  Future<bool> skipNext() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await _post(
        Uri.parse('https://api.spotify.com/v1/me/player/next'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> skipPrevious() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await _post(
        Uri.parse('https://api.spotify.com/v1/me/player/previous'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  bool _playbackStateFailed = false;

  /// Whether the last [getPlaybackState] returned null because the request
  /// failed (no network, rate limit, server error) rather than because
  /// Spotify has no active session.
  bool get lastPlaybackStateFailed => _playbackStateFailed;

  Future<Map<String, dynamic>?> getPlaybackState() async {
    _playbackStateFailed = true;
    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        _playbackStateFailed = false;
        return json.decode(response.body);
      }
      // 204 (or an empty 200): no active session.
      if (response.statusCode == 204 || response.statusCode == 200) {
        _playbackStateFailed = false;
      }
    } catch (e) {
      _log.severe('Spotify playback state error: $e');
    }
    return null;
  }

  /// Puts [uri] in Spotify's queue (after what's queued already), on the
  /// device playing. For when App Remote's link is down.
  Future<bool> addToQueue(String uri) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;
    try {
      final response = await _post(
        Uri.parse('https://api.spotify.com/v1/me/player/queue?uri=${Uri.encodeQueryComponent(uri)}'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      _log.warning('Spotify queue (Web API) failed: $e');
      return false;
    }
  }

  /// The song Spotify plays next if its "next" is pressed (the first of
  /// its queue, autoplay included), or null when unknown.
  Future<String?> nextInQueue() async {
    await _ensureValidToken();
    if (_accessToken == null) return null;
    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me/player/queue'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final queue = (json.decode(response.body) as Map?)?['queue'];
      if (queue is! List || queue.isEmpty) return null;
      final first = queue.first;
      return first is Map ? first['uri'] as String? : null;
    } catch (e) {
      _log.fine('Spotify queue lookup failed: $e');
      return null;
    }
  }

  Future<void> _saveTokens() async {
    if (_accessToken != null) {
      await _secureStorage.write(key: _tokenKey, value: _accessToken!);
    }
    if (_refreshToken != null) {
      await _secureStorage.write(key: _refreshKey, value: _refreshToken!);
    }
    if (_tokenExpiry != null) {
      await _secureStorage.write(
        key: _expiryKey,
        value: _tokenExpiry!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _profile = null;
    _isPremium = false;
    _phoneDeviceId = null;
    _preferredDeviceId = null;
    _preferredDeviceName = null;

    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshKey);
    await _secureStorage.delete(key: _expiryKey);
    await _secureStorage.delete(key: _profileKey);
  }
}
