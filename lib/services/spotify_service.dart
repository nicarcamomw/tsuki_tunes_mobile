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

import 'storage_service.dart';

class SpotifyService {
  // Every Spotify request is bounded: a stalled connection must fail (and
  // let playback fall back) instead of leaving play or login waiting forever.
  static const _apiTimeout = Duration(seconds: 10);
  static const _authTimeout = Duration(seconds: 15);

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(_apiTimeout);

  static Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(_apiTimeout);

  static Future<http.Response> _post(Uri url,
          {Map<String, String>? headers, Object? body, Duration timeout = _apiTimeout}) =>
      http.post(url, headers: headers, body: body).timeout(timeout);

  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static const _redirectUri = 'com.tsuki.tsukitunesmobile://spotify-callback';
  static const _scopes =
      'streaming user-read-private '
      'user-read-playback-state user-modify-playback-state '
      'user-read-currently-playing user-library-read user-top-read';

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
  String? _activeDeviceName;
  Completer<void>? _refreshLock;

  // URI cache: deezer_id / query -> spotify_uri (persisted in SharedPreferences)
  final Map<String, String> _uriCache = {};
  bool _uriCacheLoaded = false;
  static const int _maxUriCacheEntries = 2000;
  Timer? _saveCacheTimer;

  bool get isConnected => _accessToken != null;
  bool get isPremium => _isPremium;
  Map<String, dynamic>? get profile => _profile;
  String? get lastError => _lastError;
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
      return images.first['url'];
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
      debugPrint('[SpotifyService] error loading URI cache: $e');
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
  void populateUriCacheForTesting(Map<String, String> cache) {
    _uriCache.addAll(cache);
    _uriCacheLoaded = true;
  }

  @visibleForTesting
  void clearUriCache() {
    _uriCache.clear();
    StorageService().saveSpotifyUriCache({});
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
        callbackUrlScheme: 'com.tsuki.tsukitunesmobile',
      );

      final uri = Uri.parse(result);
      if (uri.queryParameters.containsKey('error')) {
        _lastError = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
        debugPrint('Spotify auth redirect error: $_lastError');
        return false;
      }

      final returnedState = uri.queryParameters['state'];
      if (returnedState != state) {
        _lastError = 'oauth_state_mismatch';
        debugPrint('Spotify auth: OAuth state mismatch (CSRF protection)');
        return false;
      }

      final code = uri.queryParameters['code'];
      if (code == null) {
        _lastError = 'auth_code_not_found';
        return false;
      }

      return await _exchangeCode(code, codeVerifier);
    } catch (e) {
      debugPrint('Spotify connect error: $e');
      final errStr = e.toString();
      if (errStr.contains('CANCELED') || errStr.contains('user_canceled')) {
        _lastError = 'canceled_by_user';
      } else {
        _lastError = 'connect_error: $e';
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
        debugPrint('Spotify exchange failed (${response.statusCode})');
        try {
          final data = json.decode(response.body);
          _lastError = data['error_description'] ?? data['error'] ?? 'auth_failed_${response.statusCode}';
        } catch (_) {
          _lastError = 'server_error_${response.statusCode}';
        }
        return false;
      }

      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _tokenExpiry =
          DateTime.now().add(Duration(seconds: data['expires_in']));

      await _saveTokens();
      await _fetchProfile();
      return _accessToken != null;
    } catch (e) {
      debugPrint('Spotify exchange error: $e');
      _lastError = 'network_error: $e';
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
        final data = json.decode(response.body);
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
          final data = json.decode(response.body);
          if (data['error'] == 'invalid_grant') {
            debugPrint('Spotify refresh token invalid_grant: disconnecting');
            await disconnect();
          }
        } catch (_) {}
      } else {
        debugPrint('Spotify refresh transient status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Spotify refresh network error: $e');
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
        _profile = json.decode(response.body);
        _isPremium = _profile?['product'] == 'premium';
        await _secureStorage.write(key: _profileKey, value: json.encode(_profile));
      }
    } catch (e) {
      debugPrint('Spotify profile error: $e');
    }
  }

  Future<bool> openSpotifyApp() async {
    final uri = Uri.parse('spotify:');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Spotify app: $e');
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
      debugPrint('Spotify: using locally cached URI for "$title" (${trackId ?? 'no-id'}): $cachedUri');
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
          debugPrint('Spotify: ISRC match "${items.first['name']}" ($resolvedIsrc)');
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
          final artists = (item['artists'] as List?) ?? [];
          final artistMatches = artists.any((a) {
            final spotifyArtist = _normalize(a['name'] as String? ?? '');
            return wantedArtists.any((w) =>
                spotifyArtist == w ||
                spotifyArtist.contains(w) ||
                w.contains(spotifyArtist));
          });
          if (artistMatches) {
            final resolvedUri = item['uri'] as String;
            debugPrint('Spotify: title+artist match "${item['name']}"');
            _saveToCache(trackId, title, artist, resolvedUri);
            return resolvedUri;
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify search error: $e');
    }
    debugPrint('Spotify: no reliable match for "$title" by "$artist"');
    return null;
  }

  Future<List<dynamic>?> _searchItems(String query, {required int limit}) async {
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
      final data = json.decode(response.body);
      return data['tracks']?['items'] as List?;
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

  Future<String?> getActiveDeviceId() async {
    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final response = await _get(
        Uri.parse('https://api.spotify.com/v1/me/player/devices'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = data['devices'] as List?;
        if (devices != null && devices.isNotEmpty) {
          for (final d in devices) {
            debugPrint('Spotify device: ${d['name']} (${d['type']}) active=${d['is_active']}');
          }
          // Prefer smartphone, then active device, then first
          final smartphone = devices.cast<Map<String, dynamic>>().where(
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
          debugPrint('Spotify chosen device: $_activeDeviceName (${chosen['type']})');
          return deviceId;
        }
        _activeDeviceName = null;
        debugPrint('Spotify: no devices found');
      }
    } catch (e) {
      debugPrint('Spotify devices error: $e');
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
        final data = json.decode(response.body);
        final devices = (data['devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return devices;
      }
    } catch (e) {
      debugPrint('Spotify getDevices error: $e');
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
      debugPrint('Spotify transfer: ${response.statusCode}');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Spotify transfer error: $e');
      return false;
    }
  }

  Future<String?> ensureActiveDevice() async {
    final devices = await getDevices();
    if (devices.isEmpty) {
      debugPrint('Spotify: no devices available at all');
      return null;
    }

    for (final d in devices) {
      debugPrint('Spotify device: ${d['name']} (${d['type']}) active=${d['is_active']}');
    }

    final smartphones = devices.where((d) => d['type'] == 'Smartphone').toList();

    // If a smartphone is already active, use it
    final activePhone = smartphones.where((d) => d['is_active'] == true).toList();
    if (activePhone.isNotEmpty) {
      debugPrint('Spotify: using active smartphone ${activePhone.first['name']}');
      return activePhone.first['id'] as String?;
    }

    // If there's a smartphone but not active, transfer to it
    if (smartphones.isNotEmpty) {
      final phoneId = smartphones.first['id'] as String?;
      if (phoneId != null) {
        debugPrint('Spotify: forcing playback to smartphone ${smartphones.first['name']}');
        await transferPlayback(phoneId);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return phoneId;
    }

    // No smartphone found — do NOT fall back to other device types (TV,
    // speaker, etc.).  Returning null lets the caller use App Remote which
    // plays on the local phone only.
    debugPrint('Spotify: no Smartphone device found, skipping non-phone devices');
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
      // non-phone (TV, speaker, etc.).
      final targetDevice = deviceId ?? await ensureActiveDevice();
      if (targetDevice == null) {
        debugPrint('Spotify play: no smartphone device available');
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

      debugPrint('Spotify play: ${response.statusCode} (device=$targetDevice)');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
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
      debugPrint('Spotify play failed, forcing transfer and retry');
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
      debugPrint('Spotify play retry: ${retry.statusCode}');
      return retry.statusCode == 204 || retry.statusCode == 200;
    } catch (e) {
      debugPrint('Spotify play error: $e');
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
      debugPrint('Spotify pause error: $e');
      return false;
    }
  }

  Future<bool> resume() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final deviceId = await ensureActiveDevice();
      if (deviceId == null) {
        debugPrint('Spotify resume: no smartphone device, skipping Web API');
        return false;
      }
      final url =
          'https://api.spotify.com/v1/me/player/play?device_id=$deviceId';
      final response = await _put(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      debugPrint('Spotify resume response: ${response.statusCode}');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Spotify resume error: $e');
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
      debugPrint('Spotify seek error: $e');
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
      debugPrint('Spotify playback state error: $e');
    }
    return null;
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

    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshKey);
    await _secureStorage.delete(key: _expiryKey);
    await _secureStorage.delete(key: _profileKey);
  }
}
