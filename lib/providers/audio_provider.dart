import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:spotify_sdk/spotify_sdk.dart' hide Track;
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/spotify_service.dart';
import '../services/spotify_web_player.dart';

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

  // Prefetch next track URI
  String? _prefetchedUri;
  String? _prefetchedForTrackId;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _stateSub;
  Timer? _spotifyPositionTimer;

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
  bool get useSpotify => _useSpotify && _spotifyActive;
  SpotifyService get spotify => _spotify;
  String? get lastSpotifyError => _lastSpotifyError;

  AudioProvider() {
    _initSubscriptions();
    _initSpotify();
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
      debugPrint('Spotify native error: $error');
      _lastSpotifyError = error;
      notifyListeners();
    };

    final token = await _spotify.getValidToken();
    debugPrint('Spotify: connecting native player with token=${token != null}');
    final connected = await _nativePlayer.connect(accessToken: token);
    _spotifyActive = connected;
    if (connected) {
      debugPrint('Spotify native player connected');
      // Transfer playback to the phone
      try {
        await SpotifySdk.switchToLocalDevice();
        debugPrint('Spotify: switched to local device');
      } catch (e) {
        debugPrint('Spotify: switchToLocalDevice error: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
      final deviceId = await _spotify.getActiveDeviceId();
      debugPrint('Spotify: device after connect = $deviceId');
    } else {
      debugPrint('Spotify native player failed to connect');
    }
    notifyListeners();
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

    final wasPlaying = _isPlaying;
    _isPlaying = !paused;
    _isBuffering = false;
    _position = Duration(milliseconds: positionMs);

    if (durationMs > 0) {
      _duration = Duration(milliseconds: durationMs);
    }

    // Start/stop position timer based on play state
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
      if (_isPlaying && _spotifyActive) {
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
        notifyListeners();
      }
    });

    _durSub = _service.durationStream.listen((dur) {
      if (!_spotifyActive && dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    _bufSub = _service.bufferedPositionStream.listen((buf) {
      if (!_spotifyActive) {
        _bufferedPosition = buf;
        notifyListeners();
      }
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
    });
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

    _currentTrack = track;
    _position = Duration.zero;
    _duration = Duration(
        seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    _isBuffering = true;
    notifyListeners();

    try {
      if (_useSpotify && _spotifyActive) {
        await _playViaSpotify(track);
      } else {
        await _service.playTrack(track);
      }
      onTrackStarted?.call(track);
      _prefetchNextTrack();
    } catch (e) {
      _isBuffering = false;
      notifyListeners();
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> _playViaSpotify(Track track) async {
    _lastSpotifyError = null;

    // Stop just_audio to release audio focus
    try {
      await _service.stop();
    } catch (_) {}

    // Use prefetched URI if available
    String? uri;
    if (_prefetchedForTrackId == track.id && _prefetchedUri != null) {
      uri = _prefetchedUri;
      _prefetchedUri = null;
      _prefetchedForTrackId = null;
      debugPrint('Spotify: using prefetched URI for "${track.title}"');
    } else {
      debugPrint('Spotify: searching "${track.title}" by "${track.artistName}"');
      uri = await _spotify.searchTrack(track.title, track.artistName);
    }

    if (uri == null) {
      debugPrint('Spotify: track not found "${track.title}"');
      _lastSpotifyError = 'No encontrada en Spotify, usando preview';
      await _service.playTrack(track);
      _isBuffering = false;
      notifyListeners();
      return;
    }

    debugPrint('Spotify: found URI=$uri, playing via Web API...');
    final played = await _spotify.play(trackUri: uri);
    debugPrint('Spotify: Web API play result=$played');

    if (!played) {
      debugPrint('Spotify: Web API play failed, falling back to preview');
      _lastSpotifyError = 'Error de Spotify, usando preview';
      await _service.playTrack(track);
      _isBuffering = false;
      notifyListeners();
      return;
    }

    _isPlaying = true;
    _isBuffering = false;
    _position = Duration.zero;
    _startPositionTimer();
    notifyListeners();
  }

  void _prefetchNextTrack() {
    if (!_useSpotify || !_spotifyActive) return;
    if (_currentIndex < 0 || _currentIndex >= _queue.length - 1) return;

    final nextTrack = _queue[_currentIndex + 1];
    _spotify.searchTrack(nextTrack.title, nextTrack.artistName).then((uri) {
      _prefetchedUri = uri;
      _prefetchedForTrackId = nextTrack.id;
    });
  }

  Future<void> togglePlay() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    if (_spotifyActive) {
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

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await playTrack(_queue[_currentIndex]);
  }

  Future<void> seek(Duration pos) async {
    _position = pos;
    notifyListeners();

    if (_spotifyActive) {
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

  void _handleTrackCompleted() {
    if (_isLoop) {
      seek(Duration.zero);
      if (_spotifyActive) {
        _spotify.resume();
      } else {
        _service.resume();
      }
    } else {
      next();
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _stopPositionTimer();
    _nativePlayer.dispose();
    _service.dispose();
    super.dispose();
  }
}
