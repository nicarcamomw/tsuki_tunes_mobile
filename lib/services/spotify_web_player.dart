import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

/// Spotify App Remote (the native SDK): talks to the Spotify app on this
/// phone directly. Connecting also launches/wakes the Spotify app, which the
/// Web API cannot do when the system has frozen or killed it.
class SpotifyNativePlayer {
  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static const _redirectUrl = 'com.tsuki.tsukitunesmobile://spotify-callback';

  bool _isConnected = false;
  String? _deviceId;
  StreamSubscription? _stateSub;
  Future<bool>? _connecting;

  // Last state reported by the Spotify app.
  String? _lastTrackUri;
  bool _lastPaused = true;

  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  String? get lastTrackUri => _lastTrackUri;

  /// Whether the Spotify app reports [uri] as the current, unpaused track.
  bool isPlayingUri(String uri) =>
      _isConnected && _lastTrackUri == uri && !_lastPaused;

  void Function(int positionMs, int durationMs, bool paused)? onStateChanged;
  void Function(String error)? onError;

  /// Connects once; concurrent callers share the same attempt.
  Future<bool> connect({String? accessToken}) {
    if (_isConnected) return Future.value(true);
    return _connecting ??= _connect(accessToken).whenComplete(() {
      _connecting = null;
    });
  }

  Future<bool> _connect(String? accessToken) async {
    try {
      final result = await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUrl,
        accessToken: accessToken,
        scope: 'streaming app-remote-control user-modify-playback-state',
      );
      _isConnected = result;
      if (_isConnected) _startListening();
      debugPrint('SpotifyNative: connected=$_isConnected');
      return _isConnected;
    } catch (e) {
      debugPrint('SpotifyNative: connect error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  void _startListening() {
    if (_stateSub != null) return;
    _stateSub = SpotifySdk.subscribePlayerState().listen(
      (state) {
        final track = state.track;
        _lastTrackUri = track?.uri;
        _lastPaused = state.isPaused;
        if (track == null) return;
        onStateChanged?.call(
          state.playbackPosition,
          track.duration,
          state.isPaused,
        );
      },
      onError: (e) {
        debugPrint('SpotifyNative: state error: $e');
      },
    );
  }

  /// Plays [uri] in the Spotify app through App Remote.
  Future<bool> playUri(String uri) async {
    if (!_isConnected) return false;
    try {
      await SpotifySdk.play(spotifyUri: uri);
      return true;
    } catch (e) {
      debugPrint('SpotifyNative: play error: $e');
      return false;
    }
  }

  Future<void> pause() async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.pause();
    } catch (e) {
      debugPrint('SpotifyNative: pause error: $e');
    }
  }

  Future<void> resume() async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.resume();
    } catch (e) {
      debugPrint('SpotifyNative: resume error: $e');
    }
  }

  Future<void> seekTo(int positionMs) async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
    } catch (e) {
      debugPrint('SpotifyNative: seek error: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _stateSub?.cancel();
    } catch (_) {
      // The platform stream may already be gone ("No active stream to cancel").
    }
    _stateSub = null;
    try {
      await SpotifySdk.disconnect();
    } catch (_) {}
    _isConnected = false;
    _deviceId = null;
    _lastTrackUri = null;
    _lastPaused = true;
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
