import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'storage_service.dart';

class SpotifyService {
  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static const _redirectUri = 'com.tsuki.tsukitunesmobile://spotify-callback';
  static const _scopes =
      'streaming user-read-private user-read-email '
      'user-read-playback-state user-modify-playback-state '
      'user-read-currently-playing user-library-read user-top-read';

  static const _tokenKey = 'spotify_access_token';
  static const _refreshKey = 'spotify_refresh_token';
  static const _expiryKey = 'spotify_token_expiry';
  static const _profileKey = 'spotify_profile';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
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
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
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

  Future<void> _fetchProfile() async {
    if (_accessToken == null) return;

    try {
      final response = await http.get(
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

  Future<String?> searchTrack(String title, String artist, {String? trackId}) async {
    await _ensureUriCacheLoaded();

    final cachedUri = _getFromCache(trackId, title, artist);
    if (cachedUri != null) {
      debugPrint('Spotify: using locally cached URI for "$title" (${trackId ?? 'no-id'}): $cachedUri');
      return cachedUri;
    }

    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final query = Uri.encodeComponent('track:$title artist:$artist');
      final response = await http.get(
        Uri.parse(
            'https://api.spotify.com/v1/search?q=$query&type=track&limit=10'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['tracks']?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final normalizedArtist = artist.toLowerCase().trim();
          final normalizedTitle = title.toLowerCase().trim();

          // Find best match: exact artist + title match first
          for (final item in items) {
            final artists = (item['artists'] as List?) ?? [];
            final trackName = (item['name'] as String? ?? '').toLowerCase().trim();
            for (final a in artists) {
              final spotifyArtist = (a['name'] as String? ?? '').toLowerCase().trim();
              if (spotifyArtist == normalizedArtist && trackName == normalizedTitle) {
                final resolvedUri = item['uri'] as String;
                debugPrint('Spotify: exact match "${item['name']}" by "${a['name']}"');
                _saveToCache(trackId, title, artist, resolvedUri);
                return resolvedUri;
              }
            }
          }

          // Fallback: artist name contains match
          for (final item in items) {
            final artists = (item['artists'] as List?) ?? [];
            for (final a in artists) {
              final spotifyArtist = (a['name'] as String? ?? '').toLowerCase().trim();
              if (spotifyArtist.contains(normalizedArtist) || normalizedArtist.contains(spotifyArtist)) {
                final resolvedUri = item['uri'] as String;
                debugPrint('Spotify: partial match "${item['name']}" by "${a['name']}"');
                _saveToCache(trackId, title, artist, resolvedUri);
                return resolvedUri;
              }
            }
          }

          // Last resort: first result
          final firstUri = items.first['uri'] as String;
          debugPrint('Spotify: no artist match, using first result "${items.first['name']}"');
          _saveToCache(trackId, title, artist, firstUri);
          return firstUri;
        }
      }
    } catch (e) {
      debugPrint('Spotify search error: $e');
    }
    return null;
  }

  Future<String?> getActiveDeviceId() async {
    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final response = await http.get(
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
      final response = await http.get(
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

  Future<bool> _transferPlayback(String deviceId) async {
    try {
      final response = await http.put(
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

    // Check if any device is already active
    final active = devices.where((d) => d['is_active'] == true).toList();
    if (active.isNotEmpty) {
      return active.first['id'] as String?;
    }

    // No active device — transfer to the best one
    final smartphone = devices.where((d) => d['type'] == 'Smartphone').toList();
    final target = smartphone.isNotEmpty ? smartphone.first : devices.first;
    final targetId = target['id'] as String?;

    if (targetId != null) {
      debugPrint('Spotify: transferring playback to ${target['name']}');
      await _transferPlayback(targetId);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return targetId;
  }

  Future<bool> play({String? trackUri, List<String>? trackUris, String? deviceId}) async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      // Ensure we have an active device
      final targetDevice = deviceId ?? await ensureActiveDevice();

      final body = <String, dynamic>{};
      if (trackUris != null && trackUris.isNotEmpty) {
        body['uris'] = trackUris;
      } else if (trackUri != null) {
        body['uris'] = [trackUri];
      }

      final url = targetDevice != null
          ? 'https://api.spotify.com/v1/me/player/play?device_id=$targetDevice'
          : 'https://api.spotify.com/v1/me/player/play';
      final response = await http.put(
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

      // Play failed — try transfer + retry once
      if (targetDevice != null) {
        debugPrint('Spotify play failed, forcing transfer and retry');
        await _transferPlayback(targetDevice);
        await Future.delayed(const Duration(milliseconds: 800));

        final retry = await http.put(
          Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$targetDevice'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        );
        debugPrint('Spotify play retry: ${retry.statusCode}');
        return retry.statusCode == 204 || retry.statusCode == 200;
      }

      return false;
    } catch (e) {
      debugPrint('Spotify play error: $e');
      return false;
    }
  }

  Future<bool> pause() async {
    await _ensureValidToken();
    if (_accessToken == null) return false;

    try {
      final response = await http.put(
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
      final url = deviceId != null
          ? 'https://api.spotify.com/v1/me/player/play?device_id=$deviceId'
          : 'https://api.spotify.com/v1/me/player/play';
      final response = await http.put(
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
      final response = await http.put(
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
      final response = await http.post(
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
      final response = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player/previous'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPlaybackState() async {
    await _ensureValidToken();
    if (_accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return json.decode(response.body);
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
