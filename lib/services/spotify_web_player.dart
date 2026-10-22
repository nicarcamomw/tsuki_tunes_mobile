import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class SpotifyNativePlayer {
  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static const _redirectUrl = 'com.tsuki.tsukitunesmobile://spotify-callback';

  bool _isConnected = false;
  String? _deviceId;
  StreamSubscription? _stateSub;

  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;

  void Function(int positionMs, int durationMs, bool paused)? onStateChanged;
  void Function(String error)? onError;

  Future<bool> connect({String? accessToken}) async {
    try {
      final result = await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUrl,
        accessToken: accessToken,
        scope: 'streaming app-remote-control user-modify-playback-state',
      );
      _isConnected = result;
      if (_isConnected) {
        _startListening();
      }
      debugPrint('SpotifyNative: connected=$_isConnected');
      return _isConnected;
    } catch (e) {
      debugPrint('SpotifyNative: connect error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  void _startListening() {
    _stateSub?.cancel();
    _stateSub = SpotifySdk.subscribePlayerState().listen(
      (state) {
        final track = state.track;
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

  /// Plays [uri] through App Remote. Unlike the Web API this talks to the
  /// Spotify app process directly, which also wakes it if the system froze
  /// it in the background.
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

  Future<void> disconnect() async {
    unawaited(_stateSub?.cancel());
    _stateSub = null;
    try {
      await SpotifySdk.disconnect();
    } catch (_) {}
    _isConnected = false;
    _deviceId = null;
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
