import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:spotify_sdk/spotify_sdk.dart' hide Track;
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/audio_precache_service.dart';
import '../services/spotify_service.dart';
import '../services/spotify_web_player.dart';
import '../services/storage_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayerService _service = AudioPlayerService();
  final SpotifyService _spotify = SpotifyService();
  final SpotifyNativePlayer _nativePlayer = SpotifyNativePlayer();

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isShuffle = false;
  bool _isLoop = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 30);
  Duration _bufferedPosition = Duration.zero;

  bool _useSpotify = false;
  bool _spotifyActive = false;
  String? _lastSpotifyError;
  String? _lastPlaybackError;

  // Prefetch next track URI
  String? _prefetchedUri;
  String? _prefetchedForTrackId;

  bool _completionHandled = false;
  bool _crossfadeTriggered = false;
  int _crossfadeSeconds = 3;
  DateTime _lastPlayStart = DateTime(2000);
  int _playGeneration = 0;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;
  Timer? _spotifyPositionTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxPlaybackRetries = 3;

  Function(Track)? onTrackStarted;

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  bool get isLoop => _isLoop;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  bool get useSpotify => _useSpotify;
  SpotifyService get spotify => _spotify;
  String? get lastSpotifyError => _lastSpotifyError;
  String? get lastPlaybackError => _lastPlaybackError;
  int get crossfadeSeconds => _crossfadeSeconds;

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    notifyListeners();
    await StorageService().saveCrossfadeSeconds(_crossfadeSeconds);
  }

  AudioProvider() {
    _initSubscriptions();
    _initSpotify();
    _initCrossfade();
  }

  Future<void> _initCrossfade() async {
    try {
      _crossfadeSeconds = await StorageService().getCrossfadeSeconds();
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioProvider] Error loading saved crossfade: $e');
    }
  }

  Future<void> _initSpotify() async {
    await _spotify.loadSavedState();
    _useSpotify = _spotify.isConnected && _spotify.isPremium;
    if (_useSpotify) {
      await _connectNativePlayer();
    }
  }

  Future<void> _connectNativePlayer() async {
    _nativePlayer.onStateChanged = _onNativeStateChanged;
    _nativePlayer.onError = (error) {
      debugPrint('Spotify native background notice: $error');
    };

    final token = await _spotify.getValidToken();
    if (token == null) {
      debugPrint('Spotify: no valid token, skipping native connect');
      _spotifyActive = false;
      _useSpotify = false;
      notifyListeners();
      return;
    }

    debugPrint('Spotify: connecting native player with token');
    var connected = await _nativePlayer.connect(accessToken: token);

    if (!connected) {
      debugPrint('Spotify: native connect failed, launching Spotify app...');
      await _spotify.openSpotifyApp();
      await Future.delayed(const Duration(seconds: 4));

      final freshToken = await _spotify.getValidToken();
      if (freshToken != null) {
        connected = await _nativePlayer.connect(accessToken: freshToken);
        debugPrint('Spotify: retry native connect after app launch: $connected');
      }
    }

    _spotifyActive = connected;
    if (connected) {
      debugPrint('Spotify native player connected');
      try {
        await SpotifySdk.switchToLocalDevice();
        debugPrint('Spotify: switched to local device');
      } catch (e) {
        debugPrint('Spotify: switchToLocalDevice error: $e');
      }
    }

    // Pre-warm Web API device with retries (Spotify may need time to register)
    _activateDeviceInBackground();

    notifyListeners();
  }

  Future<void> _activateDeviceInBackground() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final deviceId = await _spotify.ensureActiveDevice();
        if (deviceId != null) {
          debugPrint('Spotify: startup device ready: $deviceId');
          return;
        }
      } catch (e) {
        debugPrint('Spotify: startup device attempt $attempt error: $e');
      }
      await Future.delayed(Duration(seconds: 2 + attempt * 2));
    }
    debugPrint('Spotify: no device activated at startup (will retry on play)');
  }

  Future<void> updateSpotifyState() async {
    final wasSpotify = _useSpotify;
    _useSpotify = _spotify.isConnected && _spotify.isPremium;

    if (_useSpotify && !wasSpotify) {
      await _connectNativePlayer();
    } else if (!_useSpotify && wasSpotify) {
      _spotifyActive = false;
      _stopPositionTimer();
      await _nativePlayer.disconnect();
    }

    notifyListeners();
  }

  void _onNativeStateChanged(int positionMs, int durationMs, bool paused) {
    if (!_spotifyActive) return;

    // Ignore stale SDK events from previous track for 3 seconds after new play
    final msSincePlay = DateTime.now().difference(_lastPlayStart).inMilliseconds;
    if (msSincePlay < 3000) return;

    final wasPlaying = _isPlaying;
    _isPlaying = !paused;
    _isBuffering = false;
    _position = Duration(milliseconds: positionMs);

    if (durationMs > 0) {
      _duration = Duration(milliseconds: durationMs);
    }

    if (_isPlaying) {
      _startPositionTimer();
    } else {
      _stopPositionTimer();
    }

    // Track ended detection
    if (paused && wasPlaying && positionMs == 0) {
      _stopPositionTimer();
      _handleTrackCompleted();
      return;
    }

    notifyListeners();
  }

  void _startPositionTimer() {
    _spotifyPositionTimer?.cancel();
    _spotifyPositionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_isPlaying && _useSpotify) {
        _position += const Duration(milliseconds: 500);
        if (_position >= _duration && _duration > Duration.zero) {
          _stopPositionTimer();
          _handleTrackCompleted();
        } else {
          notifyListeners();
        }
      }
    });
  }

  void _stopPositionTimer() {
    _spotifyPositionTimer?.cancel();
    _spotifyPositionTimer = null;
  }

  void _initSubscriptions() {
    _posSub = _service.positionStream.listen((pos) {
      if (!_spotifyActive) {
        _position = pos;
        _checkCrossfade(pos);
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AudioProvider] positionStream error: $e');
    });

    _durSub = _service.durationStream.listen((dur) {
      if (!_spotifyActive && dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AudioProvider] durationStream error: $e');
    });

    _bufSub = _service.bufferedPositionStream.listen((buf) {
      if (!_spotifyActive) {
        _bufferedPosition = buf;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AudioProvider] bufferedPositionStream error: $e');
    });

    _stateSub = _service.playerStateStream.listen((state) {
      if (!_spotifyActive) {
        _isPlaying = state.playing;
        _isBuffering = state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;

        if (state.processingState == ProcessingState.completed) {
          _handleTrackCompleted();
        }

        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AudioProvider] playerStateStream error: $e');
      _handlePlaybackError(e);
    });

    _eventSub = _service.playbackEventStream.listen((_) {
      // Stream monitors native audio pipeline
    }, onError: (e) {
      debugPrint('[AudioProvider] playbackEventStream error: $e');
      _handlePlaybackError(e);
    });
  }

  void _handlePlaybackError(Object error) {
    if (_useSpotify || _currentTrack == null) return;
    if (_retryTimer?.isActive == true) return;

    if (_retryCount < _maxPlaybackRetries) {
      _retryCount++;
      _isBuffering = true;
      _lastPlaybackError = null;
      notifyListeners();

      final delayMs = 1000 * _retryCount;
      debugPrint('[AudioProvider] Retrying playback in ${delayMs}ms (attempt $_retryCount/$_maxPlaybackRetries) at position $_position');

      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(milliseconds: delayMs), () async {
        final track = _currentTrack;
        if (track != null) {
          try {
            await _service.playTrack(track, initialPosition: _position);
            _retryCount = 0;
            _isBuffering = false;
            _isPlaying = true;
            _lastPlaybackError = null;
            notifyListeners();
          } catch (e) {
            debugPrint('[AudioProvider] Auto-retry attempt #$_retryCount failed: $e');
            if (_retryCount >= _maxPlaybackRetries) {
              _isBuffering = false;
              _isPlaying = false;
              _lastPlaybackError = 'playback_error';
              notifyListeners();
            } else {
              _handlePlaybackError(e);
            }
          }
        }
      });
    } else {
      _retryCount = 0;
      _isBuffering = false;
      _isPlaying = false;
      _lastPlaybackError = 'playback_error';
      notifyListeners();
    }
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List.from(newQueue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _retryTimer?.cancel();
    _retryCount = 0;
    _currentTrack = track;
    _position = Duration.zero;
    _completionHandled = false;
    _crossfadeTriggered = false;
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _duration = Duration(
        seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    _isBuffering = true;
    notifyListeners();

    try {
      _lastPlaybackError = null;
      if (_useSpotify) {
        await _playViaSpotify(track);
      } else {
        await _service.playTrack(track);
      }
      if (gen != _playGeneration) return;
      onTrackStarted?.call(track);
      _prefetchNextTrack();
    } catch (e) {
      if (gen != _playGeneration) return;
      _isBuffering = false;
      _lastPlaybackError = 'playback_error';
      notifyListeners();
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> _playViaSpotify(Track track) async {
    final gen = _playGeneration;
    _lastSpotifyError = null;

    try {
      await _service.stop();
    } catch (_) {}

    String? uri;
    if (_prefetchedForTrackId == track.id && _prefetchedUri != null) {
      uri = _prefetchedUri;
      _prefetchedUri = null;
      _prefetchedForTrackId = null;
      debugPrint('Spotify: using prefetched URI for "${track.title}"');
    } else {
      debugPrint('Spotify: searching "${track.title}" by "${track.artistName}"');
      uri = await _spotify.searchTrack(track.title, track.artistName);
      if (gen != _playGeneration) return;
    }

    if (uri == null) {
      debugPrint('Spotify: track not found "${track.title}"');
      _lastSpotifyError = 'spotify_track_unavailable';
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    debugPrint('Spotify: found URI=$uri, playing via Web API...');
    var played = await _spotify.play(trackUri: uri);
    if (gen != _playGeneration) return;
    debugPrint('Spotify: Web API play result=$played');

    if (!played) {
      debugPrint('Spotify: play failed, launching Spotify app and retrying...');
      await _spotify.openSpotifyApp();
      await Future.delayed(const Duration(seconds: 2));
      if (gen != _playGeneration) return;

      if (!_spotifyActive) {
        final token = await _spotify.getValidToken();
        if (token != null) {
          final connected = await _nativePlayer.connect(accessToken: token);
          _spotifyActive = connected;
          if (connected) {
            try {
              await SpotifySdk.switchToLocalDevice();
              debugPrint('Spotify: switched to local device after relaunch');
            } catch (e) {
              debugPrint('Spotify: switchToLocalDevice error after relaunch: $e');
            }
            await Future.delayed(const Duration(milliseconds: 500));
            if (gen != _playGeneration) return;
          }
        }
      }

      played = await _spotify.play(trackUri: uri);
      if (gen != _playGeneration) return;
      debugPrint('Spotify: retry after app launch result=$played');
    }

    if (!played) {
      debugPrint('Spotify: all play attempts failed, falling back to preview');
      _lastSpotifyError = 'spotify_open_app';
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    _isPlaying = true;
    _isBuffering = false;
    _position = Duration.zero;
    _startPositionTimer();
    notifyListeners();
    _prefetchNextTrack();
  }

  void _prefetchNextTrack() {
    if (_currentIndex < 0 || _currentIndex >= _queue.length - 1) return;

    final nextTrack = _queue[_currentIndex + 1];

    // 1. Predictive Audio Pre-caching for Deezer (Zero-latency playback)
    AudioPrecacheService().precacheTrack(nextTrack);

    // 2. Predictive URI resolution for Spotify (Zero-latency track start)
    if (_useSpotify) {
      _spotify.searchTrack(nextTrack.title, nextTrack.artistName).then((uri) {
        _prefetchedUri = uri;
        _prefetchedForTrackId = nextTrack.id;
        debugPrint('[AudioProvider] Prefetched Spotify URI for "${nextTrack.title}"');
      }).catchError((e) {
        debugPrint('[AudioProvider] Spotify prefetch non-fatal error: $e');
      });
    }
  }

  Future<void> togglePlay() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    if (_useSpotify) {
      if (_isPlaying) {
        await _spotify.pause();
        _isPlaying = false;
      } else {
        await _spotify.resume();
        _isPlaying = true;
      }
      notifyListeners();
    } else {
      if (_isPlaying) {
        _retryTimer?.cancel();
        _retryCount = 0;
        await _service.pause();
      } else {
        await _service.resume();
      }
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle && _queue.length > 1) {
      final list = List.generate(_queue.length, (i) => i)
        ..remove(_currentIndex);
      list.shuffle();
      _currentIndex = list.first;
    } else {
      _currentIndex = (_currentIndex + 1) % _queue.length;
    }

    await playTrack(_queue[_currentIndex]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex <= 0) {
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _currentIndex - 1;
    }
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> stop() async {
    _stopPositionTimer();
    _retryTimer?.cancel();
    _retryCount = 0;
    if (_useSpotify) {
      await _spotify.pause();
    }
    await _service.stop();
    _currentTrack = null;
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    _position = pos;
    _crossfadeTriggered = false;
    notifyListeners();

    if (_useSpotify) {
      await _spotify.seekTo(pos.inMilliseconds);
    } else {
      await _service.seek(pos);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleLoop() {
    _isLoop = !_isLoop;
    notifyListeners();
  }

  /// Reorders the playback queue from [oldIndex] to [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;

    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);

    // Keep currentIndex pointer in sync with current track
    if (_currentTrack != null) {
      _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
    }
    _prefetchNextTrack();
    notifyListeners();
  }

  /// Removes the track at [index] from the playback queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final wasCurrent = index == _currentIndex;
    _queue.removeAt(index);

    if (_queue.isEmpty) {
      stop();
      return;
    }

    if (wasCurrent) {
      final nextIndex = index >= _queue.length ? 0 : index;
      playTrack(_queue[nextIndex]);
    } else {
      if (_currentTrack != null) {
        _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
      }
      notifyListeners();
    }
  }

  /// Clears the entire queue except for the currently playing track.
  void clearQueue() {
    if (_currentTrack != null) {
      _queue = [_currentTrack!];
      _currentIndex = 0;
    } else {
      _queue = [];
      _currentIndex = -1;
    }
    notifyListeners();
  }

  void _handleTrackCompleted() {
    if (_completionHandled || _crossfadeTriggered) return;
    // Ignore completion events within 3 seconds of starting a new track
    if (DateTime.now().difference(_lastPlayStart).inSeconds < 3) return;
    _completionHandled = true;

    if (_isLoop && _currentTrack != null) {
      playTrack(_currentTrack!);
    } else {
      next();
    }
  }

  void _checkCrossfade(Duration pos) {
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered || _useSpotify || _spotifyActive) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (pos.inSeconds < 2) return;

    final remaining = _duration - pos;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerCrossfade();
    }
  }

  Future<void> _triggerCrossfade() async {
    if (_queue.isEmpty || _crossfadeTriggered) return;

    int nextIdx;
    if (_isShuffle && _queue.length > 1) {
      final list = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      list.shuffle();
      nextIdx = list.first;
    } else if (_currentIndex + 1 < _queue.length) {
      nextIdx = _currentIndex + 1;
    } else if (_isLoop && _queue.isNotEmpty) {
      nextIdx = 0;
    } else {
      return;
    }

    _crossfadeTriggered = true;
    final nextTrack = _queue[nextIdx];
    _currentIndex = nextIdx;
    _currentTrack = nextTrack;
    _position = Duration.zero;
    _duration = Duration(
        seconds: nextTrack.durationSeconds > 0 ? nextTrack.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;

    debugPrint('[AudioProvider] Starting crossfade to "${nextTrack.title}" (${_crossfadeSeconds}s)');
    notifyListeners();
    onTrackStarted?.call(nextTrack);
    _prefetchNextTrack();

    try {
      await _service.crossfadeTo(nextTrack, _crossfadeSeconds);
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    } catch (e) {
      debugPrint('[AudioProvider] Crossfade error: $e');
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _eventSub?.cancel();
    _stopPositionTimer();
    _retryTimer?.cancel();
    _nativePlayer.dispose();
    _service.dispose();
    super.dispose();
  }
}
