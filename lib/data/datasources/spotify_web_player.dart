import 'dart:async';
import 'package:spotify_sdk/spotify_sdk.dart';

import '../../core/constants/app_environment.dart';
import '../../core/logger.dart';


final _log = Log.named('SpotifyService');

/// Spotify App Remote (the native SDK): talks to the Spotify app on this
/// phone directly. Connecting also launches/wakes the Spotify app, which the
/// Web API cannot do when the system has frozen or killed it.
class SpotifyNativePlayer {
  static const _clientId = '455655dc7d1040f5bedad11de1a1817b';
  static final _redirectUrl = spotifyRedirectUri;

  bool _isConnected = false;
  String? _deviceId;
  String? _accessToken;
  // Cancelled through _cancelQuietly (the platform stream may already be
  // gone), which the lint can't see.
  // ignore: cancel_subscriptions
  StreamSubscription? _stateSub;
  // ignore: cancel_subscriptions
  StreamSubscription? _connectionSub;
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
  void Function()? onDisconnected;

  /// Connects once; concurrent callers share the same attempt.
  Future<bool> connect({String? accessToken}) {
    if (accessToken != null) _accessToken = accessToken;
    if (_isConnected) return Future.value(true);
    return _connecting ??= _connect(_accessToken).whenComplete(() {
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
      if (_isConnected) {
        _watchConnection();
        _startListening();
      }
      _log.info('SpotifyNative: connected=$_isConnected');
      return _isConnected;
    } catch (e) {
      _log.severe('SpotifyNative: connect error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  /// The system can kill the Spotify app at any time; without this the
  /// connection would keep reporting itself as alive and never reconnect.
  void _watchConnection() {
    if (_connectionSub != null) return;
    _connectionSub = SpotifySdk.subscribeConnectionStatus().listen(
      (status) {
        if (status.connected) {
          if (!_isConnected) {
            _isConnected = true;
            _startListening();
          }
        } else if (_isConnected) {
          _log.warning('SpotifyNative: connection lost (${status.message})');
          _markDisconnected();
        }
      },
      onError: (e) {
        _log.severe('SpotifyNative: connection status error: $e');
      },
    );
  }

  void _markDisconnected() {
    _isConnected = false;
    _lastTrackUri = null;
    _lastPaused = true;
    final sub = _stateSub;
    _stateSub = null;
    if (sub != null) unawaited(_cancelQuietly(sub));
    onDisconnected?.call();
  }

  Future<void> _cancelQuietly(StreamSubscription sub) async {
    try {
      await sub.cancel();
    } catch (_) {
      // The platform stream may already be gone ("No active stream to cancel").
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
        _log.severe('SpotifyNative: state error: $e');
      },
    );
  }

  /// Plays [uri] in the Spotify app through App Remote. A failure usually
  /// means the Spotify app died after we connected, so reconnect (which
  /// relaunches it in the background) and try once more.
  Future<bool> playUri(String uri) async {
    if (!_isConnected) return false;
    if (await _tryPlay(uri)) return true;
    _log.severe('SpotifyNative: play failed, reconnecting to relaunch Spotify');
    _markDisconnected();
    if (!await connect()) return false;
    return _tryPlay(uri);
  }

  Future<bool> _tryPlay(String uri) async {
    try {
      await SpotifySdk.play(spotifyUri: uri);
      return true;
    } catch (e) {
      _log.severe('SpotifyNative: play error: $e');
      return false;
    }
  }

  /// Puts [uri] in the Spotify app's queue, to play after the current
  /// track (joined with Spotify's crossfade). No play: what sounds now is
  /// left alone.
  Future<bool> queue(String uri) async {
    if (!_isConnected) return false;
    try {
      await SpotifySdk.queue(spotifyUri: uri);
      return true;
    } catch (e) {
      _log.severe('SpotifyNative: queue error: $e');
      return false;
    }
  }

  Future<void> pause() async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.pause();
    } catch (e) {
      _log.severe('SpotifyNative: pause error: $e');
    }
  }

  Future<void> resume() async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.resume();
    } catch (e) {
      _log.severe('SpotifyNative: resume error: $e');
    }
  }

  Future<void> seekTo(int positionMs) async {
    if (!_isConnected) return;
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
    } catch (e) {
      _log.severe('SpotifyNative: seek error: $e');
    }
  }

  /// Makes the Spotify app loop the current track ([on]) or stop repeating.
  Future<bool> setRepeatTrack(bool on) async {
    if (!_isConnected) return false;
    try {
      await SpotifySdk.setRepeatMode(
          repeatMode: on ? SpotifyRepeatMode.track : SpotifyRepeatMode.off);
      return true;
    } catch (e) {
      _log.severe('SpotifyNative: repeat error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    final stateSub = _stateSub;
    final connectionSub = _connectionSub;
    _stateSub = null;
    _connectionSub = null;
    if (stateSub != null) await _cancelQuietly(stateSub);
    if (connectionSub != null) await _cancelQuietly(connectionSub);
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
