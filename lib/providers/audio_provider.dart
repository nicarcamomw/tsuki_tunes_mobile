import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import '../core/utils/deezer_preview.dart';
import '../models/track.dart';
import '../models/repeat_mode.dart';
export '../models/repeat_mode.dart';
import '../services/audio_player_service.dart';
import '../services/audio_precache_service.dart';
import '../services/deezer_api_service.dart';
import '../services/spotify_service.dart';
import '../services/foreground_service.dart';
import '../services/spotify_web_player.dart';
import '../services/storage_service.dart';
import 'connectivity_provider.dart';

class AudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayerService _service;
  final SpotifyService _spotify = SpotifyService();
  final SpotifyNativePlayer _nativePlayer = SpotifyNativePlayer();
  final ForegroundService _foregroundService = ForegroundService();
  final StorageService _storage;
  ConnectivityProvider? _connectivityProvider;
  Timer? _persistTimer;

  @visibleForTesting
  Function(Track track)? onPrecacheTrackForTesting;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isShuffle = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 30);
  Duration _bufferedPosition = Duration.zero;

  bool _useSpotify = false;
  bool _spotifyActive = false;
  bool _spotifyFallbackActive = false;
  String? _lastSpotifyError;
  String? _lastPlaybackError;

  // Prefetch next track URI
  String? _prefetchedUri;
  String? _prefetchedForTrackId;
  String? _prefetchedTargetTrackId;
  int _prefetchGeneration = 0;
  int? _nextShuffleIndex;

  bool _completionHandled = false;
  bool _crossfadeTriggered = false;
  int _crossfadeSeconds = 3;
  bool _autoMarkListened = false;
  bool _precacheWifiOnly = false;
  // Play generation for which the "listened" threshold already fired.
  int _autoMarkedGeneration = -1;
  static const double _autoMarkThreshold = 0.8;
  DateTime _lastPlayStart = DateTime(2000);
  int _playGeneration = 0;

  // Wall-clock position tracking for Spotify (avoids timer drift)
  Duration _spotifySyncPosition = Duration.zero;
  DateTime _spotifySyncTime = DateTime(2000);
  DateTime _lastPlayCommandTime = DateTime(2000);
  // URI last sent to Spotify, to detect playback taken over elsewhere.
  String? _currentSpotifyUri;

  // Smart shuffle history — recent artistIds to avoid consecutive repeats
  final List<String> _shuffleArtistHistory = [];
  final List<String> _shuffleAlbumHistory = [];
  static const int _shuffleHistorySize = 5;
  final Random _shuffleRng = Random();

  // Playback history for shuffle previous navigation (up to 50 entries)
  final List<int> _playHistory = [];
  static const int _maxPlayHistory = 50;

  // Sleep timer
  Timer? _sleepTimer;
  DateTime? _sleepTimerDeadline;
  Duration? _sleepTimerRemaining;
  bool _stopAfterCurrentTrack = false;
  int? _sleepTimerOriginalMinutes;

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

  /// Called once per play when [autoMarkListened] is on and playback passes
  /// 80% of the track.
  Function(Track)? onListenedThreshold;

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  bool get isLoop => _repeatMode != PlaybackRepeatMode.off;
  bool get isRepeatAll => _repeatMode == PlaybackRepeatMode.all;
  bool get isRepeatOne => _repeatMode == PlaybackRepeatMode.one;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  bool get useSpotify => _useSpotify;
  bool get spotifyFallbackActive => _spotifyFallbackActive;
  SpotifyService get spotify => _spotify;
  String? get lastSpotifyError => _lastSpotifyError;
  String? get lastPlaybackError => _lastPlaybackError;
  int get crossfadeSeconds => _crossfadeSeconds;
  bool get autoMarkListened => _autoMarkListened;
  bool get precacheWifiOnly => _precacheWifiOnly;

  Future<void> setAutoMarkListened(bool enabled) async {
    _autoMarkListened = enabled;
    notifyListeners();
    await _storage.saveAutoMarkListened(enabled);
  }

  Future<void> setPrecacheWifiOnly(bool enabled) async {
    _precacheWifiOnly = enabled;
    notifyListeners();
    await _storage.savePrecacheWifiOnly(enabled);
  }

  @visibleForTesting
  void checkListenedThresholdForTesting() => _checkListenedThreshold();

  void _checkListenedThreshold() {
    if (!_autoMarkListened || _autoMarkedGeneration == _playGeneration) return;
    final track = _currentTrack;
    if (track == null || _duration <= Duration.zero) return;
    if (_position.inMilliseconds <
        _duration.inMilliseconds * _autoMarkThreshold) {
      return;
    }
    _autoMarkedGeneration = _playGeneration;
    onListenedThreshold?.call(track);
  }
  Duration? get sleepTimerRemaining {
    if (_sleepTimerDeadline != null) {
      final diff = _sleepTimerDeadline!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return _sleepTimerRemaining;
  }
  bool get isSleepTimerActive =>
      _sleepTimerDeadline != null || _sleepTimerRemaining != null || _stopAfterCurrentTrack;
  int? get sleepTimerOriginalMinutes => _sleepTimerOriginalMinutes;
  int? get nextShuffleIndex => _nextShuffleIndex;

  @visibleForTesting
  List<int> get playHistory => List.unmodifiable(_playHistory);

  void _addToPlayHistory(int index) {
    if (index >= 0 && index < _queue.length) {
      _playHistory.add(index);
      if (_playHistory.length > _maxPlayHistory) {
        _playHistory.removeAt(0);
      }
    }
  }

  @visibleForTesting
  DateTime? get sleepTimerDeadline => _sleepTimerDeadline;

  @visibleForTesting
  void setSleepTimerDeadlineForTesting(DateTime? deadline) {
    _sleepTimerDeadline = deadline;
  }

  @visibleForTesting
  void setPositionForTesting(Duration pos) {
    _position = pos;
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    notifyListeners();
    await _storage.saveCrossfadeSeconds(_crossfadeSeconds);
  }

  ConnectivityProvider? get connectivityProvider => _connectivityProvider;

  void setConnectivityProvider(ConnectivityProvider cp) {
    _connectivityProvider = cp;
  }

  bool _canPlayOffline(Track track) {
    if (_connectivityProvider?.isOnline ?? true) return true;
    return AudioPrecacheService().getCachedFilePath(track.id) != null;
  }

  @visibleForTesting
  bool canPlayOfflineForTesting(Track track) => _canPlayOffline(track);

  void _prefetchUpcoming([int count = 3]) {
    if (_queue.isEmpty) return;
    for (var i = 1; i <= count; i++) {
      final idx = (_currentIndex + i) % _queue.length;
      if (idx != _currentIndex) {
        final track = _queue[idx];
        onPrecacheTrackForTesting?.call(track);
        _precache(track);
      }
    }
  }

  @visibleForTesting
  void prefetchUpcomingForTesting([int count = 3]) => _prefetchUpcoming(count);

  AudioProvider({
    AudioPlayerService? service,
    StorageService? storage,
    ConnectivityProvider? connectivityProvider,
  })  : _service = service ?? AudioPlayerService(),
        _storage = storage ?? StorageService(),
        _connectivityProvider = connectivityProvider {
    WidgetsBinding.instance.addObserver(this);
    _initAudioSession();
    _initSubscriptions();
    _restorePlaybackState();
    _initSpotify();
    _initCrossfade();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistPlaybackState();
    }
    if (state == AppLifecycleState.resumed) {
      checkSleepTimer();
      _checkBackgroundCompletion();
      if (_useSpotify && _spotifyActive) {
        _startPositionTimer();
        _syncSpotifyPlaybackState();
      }
    }
  }

  void _checkBackgroundCompletion() {
    if (_currentTrack == null) return;
    if (_useSpotify && _spotifyActive) {
      final elapsed = DateTime.now().difference(_spotifySyncTime);
      final estimatedPos = _spotifySyncPosition + elapsed;
      if (estimatedPos >= _duration && _duration > Duration.zero) {
        _completionHandled = false;
        _crossfadeTriggered = false;
        _handleTrackCompleted();
      }
    } else {
      final state = _service.player.processingState;
      if (state == ProcessingState.completed) {
        _completionHandled = false;
        _crossfadeTriggered = false;
        _handleTrackCompleted();
      }
    }
  }

  DateTime _lastPositionPersist = DateTime(2000);

  /// Saves the position every ~10 s so a killed app resumes close to where
  /// it stopped instead of at the start of the track.
  void _maybePersistPosition() {
    final now = DateTime.now();
    if (now.difference(_lastPositionPersist).inSeconds < 10) return;
    _lastPositionPersist = now;
    _persistPlaybackState();
  }

  void _persistPlaybackState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) {
        await _storage.savePlaybackState(null);
        return;
      }
      await _storage.savePlaybackState(
        _queue,
        _currentIndex,
        _position.inMilliseconds,
      );
    });
  }

  @visibleForTesting
  void persistPlaybackStateNowForTesting() {
    _persistTimer?.cancel();
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) {
      _storage.savePlaybackState(null);
      return;
    }
    _storage.savePlaybackState(
      _queue,
      _currentIndex,
      _position.inMilliseconds,
    );
  }

  Future<void> _restorePlaybackState() async {
    try {
      final state = await _storage.getPlaybackState();
      if (state == null) return;

      if (_currentTrack != null || _queue.isNotEmpty || _isPlaying) return;

      final rawQueue = state['queue'];
      final rawIndex = state['currentIndex'];
      final rawPosMs = state['position'];

      if (rawQueue is! List || rawQueue.isEmpty) return;

      final restoredQueue = <Track>[];
      for (final item in rawQueue) {
        if (item is Map) {
          restoredQueue.add(Track.fromStorage(Map<String, dynamic>.from(item)));
        }
      }

      if (restoredQueue.isEmpty) return;

      int restoredIndex = (rawIndex is num) ? rawIndex.toInt() : 0;
      if (restoredIndex < 0 || restoredIndex >= restoredQueue.length) {
        restoredIndex = 0;
      }

      final restoredTrack = restoredQueue[restoredIndex];
      final posMs = (rawPosMs is num) ? rawPosMs.toInt() : 0;

      _queue = restoredQueue;
      _currentIndex = restoredIndex;
      _currentTrack = restoredTrack;
      _position = Duration(milliseconds: posMs);
      _duration = Duration(
          seconds: restoredTrack.durationSeconds > 0
              ? restoredTrack.durationSeconds
              : 30);
      _isPlaying = false;
      _isBuffering = false;

      _prefetchNextTrack();
      notifyListeners();
      debugPrint('[AudioProvider] Restored playback state: "${restoredTrack.title}" at ${posMs}ms (${_queue.length} tracks in queue)');
    } catch (e) {
      debugPrint('[AudioProvider] Error restoring playback state: $e');
    }
  }

  @visibleForTesting
  Future<void> restorePlaybackStateForTesting() => _restorePlaybackState();

  Future<void> _initCrossfade() async {
    try {
      _crossfadeSeconds = await _storage.getCrossfadeSeconds();
      _autoMarkListened = await _storage.getAutoMarkListened();
      _precacheWifiOnly = await _storage.getPrecacheWifiOnly();
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioProvider] Error loading saved crossfade: $e');
    }
  }

  bool _spotifyInterrupted = false;

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((event) {
        if (!_spotifyActive) return;
        if (event.begin) {
          if (_isPlaying) {
            _spotify.pause();
            _isPlaying = false;
            _stopPositionTimer();
            _spotifyInterrupted = true;
            notifyListeners();
          }
        } else {
          if (_spotifyInterrupted) {
            _spotifyInterrupted = false;
            _spotify.resume();
            _isPlaying = true;
            _lastPlayCommandTime = DateTime.now();
            _spotifySyncPosition = _position;
            _spotifySyncTime = DateTime.now();
            _startPositionTimer();
            notifyListeners();
          }
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        if (_spotifyActive && _isPlaying) {
          _spotify.pause();
          _isPlaying = false;
          _stopPositionTimer();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[AudioProvider] AudioSession config error: $e');
    }
  }

  Future<void> _initSpotify() async {
    await _spotify.loadSavedState();
    _useSpotify = _spotify.isConnected && _spotify.isPremium;
    if (_useSpotify) {
      _warmUpSpotifyDevice();
    }
  }

  void _warmUpSpotifyDevice() {
    Future.microtask(() async {
      try {
        final device = await _spotify.ensureActiveDevice();
        debugPrint('[AudioProvider] Spotify device pre-warm: ${device ?? "no device found"}');
        if (device != null) return;

        // No active device — wake Spotify via native SDK (invisible, no UI)
        final token = _spotify.accessToken;
        if (token == null) return;
        debugPrint('[AudioProvider] No Spotify device found, waking via native SDK...');
        final connected = await _nativePlayer.connect(accessToken: token);
        if (connected) {
          await Future.delayed(const Duration(milliseconds: 1500));
          final wokenDevice = await _spotify.ensureActiveDevice();
          debugPrint('[AudioProvider] Spotify native wake result: ${wokenDevice ?? "still no device"}');
        } else {
          debugPrint('[AudioProvider] Spotify native SDK connect failed during warm-up');
        }
      } catch (e) {
        debugPrint('[AudioProvider] Spotify device pre-warm error: $e');
      }
    });
  }


  Future<void> updateSpotifyState() async {
    final wasSpotify = _useSpotify;
    _useSpotify = _spotify.isConnected && _spotify.isPremium;

    if (!_useSpotify && wasSpotify) {
      _spotifyActive = false;
      _spotifyFallbackActive = false;
      _stopPositionTimer();
      await _nativePlayer.disconnect();
    } else if (_useSpotify && !wasSpotify) {
      _warmUpSpotifyDevice();
    }

    notifyListeners();
  }

  int _spotifyPollTick = 0;

  void _startPositionTimer() {
    _spotifyPositionTimer?.cancel();
    _spotifyPollTick = 0;
    _spotifyPositionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_useSpotify || !_spotifyActive || _completionHandled) return;

      _spotifyPollTick++;

      if (_isPlaying) {
        final elapsed = DateTime.now().difference(_spotifySyncTime);
        _position = _spotifySyncPosition + elapsed;
        if (_position >= _duration && _duration > Duration.zero) {
          _stopPositionTimer();
          _handleTrackCompleted();
        } else {
          _maybePersistPosition();
          _checkListenedThreshold();
          notifyListeners();
          if (_spotifyPollTick % 15 == 0) {
            _syncSpotifyPlaybackState();
          }
        }
      } else if (_currentTrack != null) {
        // While paused, poll every 5s to recover from false pause or detect external resume
        if (_spotifyPollTick % 5 == 0) {
          _syncSpotifyPlaybackState();
        }
      }
    });
  }

  Future<void> _syncSpotifyPlaybackState() async {
    try {
      final state = await _spotify.getPlaybackState();
      if (state == null || !_spotifyActive || _completionHandled) return;

      final progressMs = state['progress_ms'] as int? ?? 0;
      final isPlaying = state['is_playing'] as bool? ?? false;
      final item = state['item'] as Map<String, dynamic>?;
      final durationMs = item?['duration_ms'] as int? ?? 0;

      // Detect playback transferred to another device
      if (item != null && _currentTrack != null && _currentSpotifyUri != null) {
        final playingUri = item['uri'] as String?;
        // Spotify may relink the track to another market's version.
        final linkedUri = (item['linked_from'] as Map?)?['uri'] as String?;
        if (playingUri != null &&
            playingUri != _currentSpotifyUri &&
            linkedUri != _currentSpotifyUri) {
          debugPrint('[AudioProvider] Spotify playing different track ($playingUri vs $_currentSpotifyUri), pausing');
          _isPlaying = false;
          _stopPositionTimer();
          notifyListeners();
          return;
        }
      }

      _spotifySyncPosition = Duration(milliseconds: progressMs);
      _spotifySyncTime = DateTime.now();
      _position = _spotifySyncPosition;

      if (durationMs > 0) {
        _duration = Duration(milliseconds: durationMs);
      }

      if (!isPlaying && _isPlaying) {
        // Grace period: ignore stale pause reports right after a play command
        final sincePlayCommand = DateTime.now().difference(_lastPlayCommandTime);
        if (sincePlayCommand.inSeconds < 5) {
          debugPrint('[AudioProvider] Spotify sync: ignoring stale pause (${sincePlayCommand.inMilliseconds}ms since play command)');
          return;
        }
        if (durationMs > 0 && progressMs >= durationMs - 1000) {
          _stopPositionTimer();
          _handleTrackCompleted();
          return;
        }
        _isPlaying = false;
        notifyListeners();
        return;
      }

      if (isPlaying && !_isPlaying) {
        _isPlaying = true;
        _startPositionTimer();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[AudioProvider] Spotify state sync error: $e');
    }
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
        if (_isPlaying) {
          _maybePersistPosition();
          _checkListenedThreshold();
        }
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

  String _classifyPlaybackError(Object error, [Track? track]) {
    final errStr = error.toString().toLowerCase();

    // 1. No preview available
    if (track != null && track.previewUrl.trim().isEmpty) {
      return 'no_preview_available';
    }
    if (errStr.contains('preview is unavailable') ||
        errStr.contains('no preview') ||
        errStr.contains('preview_unavailable')) {
      return 'no_preview_available';
    }

    // 2. Network error
    if (error is SocketException ||
        error is TimeoutException ||
        errStr.contains('socketexception') ||
        errStr.contains('network') ||
        errStr.contains('connection') ||
        errStr.contains('timeout') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('unreachable') ||
        errStr.contains('timed out')) {
      return 'network_error';
    }

    // 3. Format unsupported
    if (errStr.contains('format') ||
        errStr.contains('unsupported') ||
        errStr.contains('codec') ||
        errStr.contains('decode') ||
        errStr.contains('demux') ||
        errStr.contains('extractor')) {
      return 'format_unsupported';
    }

    return 'playback_error';
  }

  @visibleForTesting
  String classifyPlaybackError(Object error, [Track? track]) =>
      _classifyPlaybackError(error, track);

  void _handlePlaybackError(Object error) {
    if ((_useSpotify && _spotifyActive && !_spotifyFallbackActive) || _currentTrack == null) return;
    if (_retryTimer?.isActive == true) return;

    final classified = _classifyPlaybackError(error, _currentTrack);
    // Non-transient errors: abort immediate retry and report specific error
    if (classified == 'no_preview_available' || classified == 'format_unsupported') {
      _retryTimer?.cancel();
      _retryCount = 0;
      _isBuffering = false;
      _isPlaying = false;
      _lastPlaybackError = classified;
      notifyListeners();
      return;
    }

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
              _lastPlaybackError = _classifyPlaybackError(e, track);
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
      _lastPlaybackError = classified;
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
      _playHistory.clear();
      _prefetchUpcoming();
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _retryTimer?.cancel();
    _retryCount = 0;
    _currentTrack = track;
    _nextShuffleIndex = null;
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

      track = await _withFreshPreview(track);
      if (gen != _playGeneration) return;

      if (!_canPlayOffline(track)) {
        _isBuffering = false;
        _lastPlaybackError = 'network_error';
        notifyListeners();
        return;
      }

      if (_useSpotify) {
        await _playViaSpotify(track);
      } else {
        try {
          await _service.playTrack(track);
        } catch (e) {
          // A stored preview URL may have been revoked before its expiry:
          // fetch a fresh one and try once more.
          if (gen != _playGeneration) return;
          final refreshed = await _withFreshPreview(track, force: true);
          if (gen != _playGeneration) return;
          if (identical(refreshed, track)) rethrow;
          track = refreshed;
          await _service.playTrack(track);
        }
      }
      if (gen != _playGeneration) return;
      onTrackStarted?.call(track);
      _foregroundService.start(
        title: track.title,
        artist: track.artistName,
      );
      _persistPlaybackState();
      _prefetchNextTrack();
    } catch (e) {
      if (gen != _playGeneration) return;
      _isBuffering = false;
      _lastPlaybackError = _classifyPlaybackError(e, track);
      notifyListeners();
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> _playViaSpotify(Track track) async {
    final gen = _playGeneration;
    _lastSpotifyError = null;

    // Gate just_audio streams immediately to prevent state interference
    _spotifyActive = true;
    _spotifyFallbackActive = false;

    try {
      await _service.stop();
    } catch (_) {}

    String? uri;
    if (_prefetchedForTrackId == track.id && _prefetchedUri != null) {
      uri = _prefetchedUri;
      _prefetchedUri = null;
      _prefetchedForTrackId = null;
      _prefetchedTargetTrackId = null;
      debugPrint('Spotify: using prefetched URI for "${track.title}"');
    } else {
      debugPrint('Spotify: searching "${track.title}" by "${track.artistName}"');
      uri = await _resolveSpotifyUri(track);
      if (gen != _playGeneration) return;
    }

    if (uri == null) {
      debugPrint('Spotify: track not found "${track.title}", falling back to preview');
      _lastSpotifyError = 'spotify_track_unavailable';
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    debugPrint('Spotify: found URI=$uri, playing via Web API...');
    _currentSpotifyUri = uri;
    var played = await _spotify.play(trackUri: uri);
    if (gen != _playGeneration) return;
    debugPrint('Spotify: Web API play result=$played');

    if (!played) {
      debugPrint('Spotify: Web API play failed, trying ensureActiveDevice...');
      await _spotify.ensureActiveDevice();
      if (gen != _playGeneration) return;
      played = await _spotify.play(trackUri: uri);
      if (gen != _playGeneration) return;
      debugPrint('Spotify: retry with ensureActiveDevice result=$played');
    }

    if (!played) {
      debugPrint('Spotify: Web API exhausted, trying native SDK device registration...');
      try {
        final token = _spotify.accessToken;
        if (token != null) {
          final connected = await _nativePlayer.connect(accessToken: token);
          if (gen != _playGeneration) return;
          if (connected) {
            debugPrint('Spotify: native SDK connected, waiting for device...');
            await Future.delayed(const Duration(milliseconds: 1500));
            if (gen != _playGeneration) return;
            await _spotify.ensureActiveDevice();
            if (gen != _playGeneration) return;
            played = await _spotify.play(trackUri: uri);
            if (gen != _playGeneration) return;
            debugPrint('Spotify: post-native-connect play result=$played');
          }
        }
      } catch (e) {
        debugPrint('Spotify: native SDK fallback error: $e');
      }
    }

    if (!played) {
      debugPrint('Spotify: all play attempts failed, falling back to preview');
      _lastSpotifyError = 'spotify_open_app';
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      try { await _nativePlayer.disconnect(); } catch (_) {}
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    _spotifyActive = true;
    _spotifyFallbackActive = false;
    _isPlaying = true;
    _isBuffering = false;
    _position = Duration.zero;
    _spotifySyncPosition = Duration.zero;
    _spotifySyncTime = DateTime.now();
    _lastPlayCommandTime = DateTime.now();
    _startPositionTimer();
    notifyListeners();
    _prefetchNextTrack();
  }

  void _precache(Track track) {
    if (_precacheWifiOnly && (_connectivityProvider?.isMetered ?? false)) {
      return;
    }
    _withFreshPreview(track).then(AudioPrecacheService().precacheTrack);
  }

  /// Returns [track] with a playable previewUrl, re-fetching it from Deezer
  /// when the signed URL has expired (or always when [force] is set, after a
  /// playback failure). The refreshed track replaces the stale one in the
  /// queue so later plays and precaching reuse the fresh URL.
  Future<Track> _withFreshPreview(Track track, {bool force = false}) async {
    final url = track.previewUrl;
    if (url.isEmpty || !DeezerPreview.isDeezerUrl(url)) return track;
    if (AudioPrecacheService().getCachedFilePath(track.id) != null) {
      return track;
    }
    if (!force && !DeezerPreview.isExpired(url)) return track;

    final fresh = await DeezerApiService().getTrack(track.id, forceRefresh: true);
    if (fresh == null || fresh.previewUrl.isEmpty || fresh.previewUrl == url) {
      return track;
    }
    debugPrint('[AudioProvider] Refreshed expired preview for "${track.title}"');
    final updated = track.copyWith(
      previewUrl: fresh.previewUrl,
      isrc: track.isrc ?? fresh.isrc,
    );
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].id == track.id) _queue[i] = updated;
    }
    if (_currentTrack?.id == track.id) _currentTrack = updated;
    return updated;
  }

  Future<String?> _resolveSpotifyUri(Track track) {
    return _spotify.searchTrack(
      track.title,
      track.artistName,
      trackId: track.id,
      isrc: track.isrc,
      isrcResolver: () async =>
          (await DeezerApiService().getTrack(track.id))?.isrc,
    );
  }

  /// Returns the upcoming track index without advancing the queue pointer.
  /// When shuffle is active, pre-determines and memoizes the next track index
  /// so background prefetching (Deezer audio precache & Spotify URI search)
  /// and actual playback (next, crossfade, track completion) target the exact same track.
  int? _peekNextIndex() {
    if (_queue.isEmpty || _currentIndex < 0) return null;

    if (_isShuffle && _queue.length > 1) {
      if (_nextShuffleIndex == null ||
          _nextShuffleIndex! < 0 ||
          _nextShuffleIndex! >= _queue.length ||
          _nextShuffleIndex == _currentIndex) {
        _nextShuffleIndex = _pickSmartNext();
      }
      return _nextShuffleIndex;
    }

    if (_currentIndex + 1 < _queue.length) {
      return _currentIndex + 1;
    } else if (_repeatMode == PlaybackRepeatMode.all && _queue.isNotEmpty) {
      return 0;
    } else if (_repeatMode == PlaybackRepeatMode.one) {
      return _currentIndex;
    }

    return null;
  }

  @visibleForTesting
  int? peekNextIndex() => _peekNextIndex();

  void _prefetchNextTrack() {
    final nextIdx = _peekNextIndex();
    if (nextIdx == null || nextIdx < 0 || nextIdx >= _queue.length) return;

    final nextTrack = _queue[nextIdx];

    // 1. Predictive Audio Pre-caching for Deezer (Zero-latency playback)
    _precache(nextTrack);

    // 2. Predictive URI resolution for Spotify (Zero-latency track start)
    if (_useSpotify) {
      if (_prefetchedTargetTrackId == nextTrack.id) return;
      _prefetchedTargetTrackId = nextTrack.id;
      _prefetchedUri = null;
      _prefetchedForTrackId = null;
      final gen = ++_prefetchGeneration;
      _resolveSpotifyUri(nextTrack).then((uri) {
        if (gen != _prefetchGeneration) return;
        _prefetchedUri = uri;
        _prefetchedForTrackId = nextTrack.id;
        debugPrint('[AudioProvider] Prefetched Spotify URI for "${nextTrack.title}"');
      }).catchError((e) {
        if (gen == _prefetchGeneration) {
          _prefetchedTargetTrackId = null;
        }
        debugPrint('[AudioProvider] Spotify prefetch non-fatal error: $e');
      });
    }
  }

  Future<void> togglePlay() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    if (_useSpotify && _spotifyActive && !_spotifyFallbackActive) {
      if (_isPlaying) {
        await _spotify.pause();
        _isPlaying = false;
        _stopPositionTimer();
      } else {
        await _spotify.resume();
        _isPlaying = true;
        _lastPlayCommandTime = DateTime.now();
        _spotifySyncPosition = _position;
        _spotifySyncTime = DateTime.now();
        _startPositionTimer();
      }
      notifyListeners();
    } else {
      if (_isPlaying) {
        _retryTimer?.cancel();
        _retryCount = 0;
        await _service.pause();
      } else {
        if (_currentTrack != null && _service.player.audioSource == null) {
          final savedPos = _position;
          await playTrack(_currentTrack!);
          if (savedPos > Duration.zero) {
            await seek(savedPos);
          }
        } else {
          await _service.resume();
        }
      }
    }
    if (!_isPlaying) _persistPlaybackState();
  }

  /// Picks the next track index using weighted scoring to avoid
  /// consecutive same-artist/album repeats. Heavier penalty for
  /// artists/albums heard most recently.
  int _pickSmartNext() {
    final candidates = <int>[];
    for (int i = 0; i < _queue.length; i++) {
      if (i != _currentIndex) candidates.add(i);
    }
    if (candidates.isEmpty) return _currentIndex;
    if (candidates.length == 1) return candidates.first;

    // Score each candidate — higher is better
    double bestScore = double.negativeInfinity;
    final scores = <double>[];

    for (final idx in candidates) {
      final track = _queue[idx];
      double score = _shuffleRng.nextDouble(); // base randomness [0, 1)

      // Penalize if artist was played recently (heavier for more recent)
      final artistPos = _shuffleArtistHistory.lastIndexOf(track.artistId);
      if (artistPos != -1) {
        final recency = _shuffleArtistHistory.length - artistPos;
        score -= 3.0 / recency; // -3.0 if last, -1.5 if second-to-last, etc.
      }

      // Penalize if album was played recently
      final albumPos = _shuffleAlbumHistory.lastIndexOf(track.albumId);
      if (albumPos != -1) {
        final recency = _shuffleAlbumHistory.length - albumPos;
        score -= 1.5 / recency;
      }

      scores.add(score);
      if (score > bestScore) bestScore = score;
    }

    // Collect all candidates within 0.3 of the best score for a tie-break
    final topTier = <int>[];
    for (int i = 0; i < candidates.length; i++) {
      if (scores[i] >= bestScore - 0.3) topTier.add(candidates[i]);
    }

    return topTier[_shuffleRng.nextInt(topTier.length)];
  }

  void _recordShuffleHistory(Track track) {
    _shuffleArtistHistory.add(track.artistId);
    if (_shuffleArtistHistory.length > _shuffleHistorySize) {
      _shuffleArtistHistory.removeAt(0);
    }
    _shuffleAlbumHistory.add(track.albumId);
    if (_shuffleAlbumHistory.length > _shuffleHistorySize) {
      _shuffleAlbumHistory.removeAt(0);
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    final isOnline = _connectivityProvider?.isOnline ?? true;
    if (!isOnline && !_queue.any((t) => _canPlayOffline(t))) {
      _lastPlaybackError = 'network_error';
      notifyListeners();
      return;
    }

    if (_isShuffle && _queue.length > 1) {
      if (!isOnline) {
        if (_nextShuffleIndex != null &&
            _nextShuffleIndex! >= 0 &&
            _nextShuffleIndex! < _queue.length &&
            _nextShuffleIndex != _currentIndex &&
            _canPlayOffline(_queue[_nextShuffleIndex!])) {
          _addToPlayHistory(_currentIndex);
          _currentIndex = _nextShuffleIndex!;
        } else {
          final cachedCandidates = [
            for (int i = 0; i < _queue.length; i++)
              if (i != _currentIndex && _canPlayOffline(_queue[i])) i
          ];
          if (cachedCandidates.isNotEmpty) {
            _addToPlayHistory(_currentIndex);
            _currentIndex = cachedCandidates[_shuffleRng.nextInt(cachedCandidates.length)];
          } else {
            _lastPlaybackError = 'network_error';
            notifyListeners();
            return;
          }
        }
      } else {
        _addToPlayHistory(_currentIndex);
        if (_nextShuffleIndex != null &&
            _nextShuffleIndex! >= 0 &&
            _nextShuffleIndex! < _queue.length &&
            _nextShuffleIndex != _currentIndex) {
          _currentIndex = _nextShuffleIndex!;
        } else {
          _currentIndex = _pickSmartNext();
        }
      }
      _nextShuffleIndex = null;
    } else {
      if (!isOnline) {
        int targetIndex = -1;
        for (int step = 1; step < _queue.length; step++) {
          final idx = (_currentIndex + step) % _queue.length;
          if (_canPlayOffline(_queue[idx])) {
            targetIndex = idx;
            break;
          }
        }
        if (targetIndex != -1) {
          _addToPlayHistory(_currentIndex);
          _currentIndex = targetIndex;
        } else if (_queue.length == 1 && _canPlayOffline(_queue[0])) {
          _currentIndex = 0;
        } else {
          _lastPlaybackError = 'network_error';
          notifyListeners();
          return;
        }
      } else {
        _addToPlayHistory(_currentIndex);
        _currentIndex = (_currentIndex + 1) % _queue.length;
      }
    }

    final nextTrack = _queue[_currentIndex];
    if (_isShuffle) _recordShuffleHistory(nextTrack);
    await playTrack(nextTrack);
    _persistPlaybackState();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final isOnline = _connectivityProvider?.isOnline ?? true;
    if (!isOnline && !_queue.any((t) => _canPlayOffline(t))) {
      _lastPlaybackError = 'network_error';
      notifyListeners();
      return;
    }

    if (_isShuffle) {
      if (_playHistory.isEmpty) {
        await seek(Duration.zero);
        return;
      }
      if (!isOnline) {
        int? targetIdx;
        while (_playHistory.isNotEmpty) {
          final prevIndex = _playHistory.removeLast();
          if (prevIndex >= 0 &&
              prevIndex < _queue.length &&
              _canPlayOffline(_queue[prevIndex])) {
            targetIdx = prevIndex;
            break;
          }
        }
        if (targetIdx != null) {
          _currentIndex = targetIdx;
        } else {
          await seek(Duration.zero);
          return;
        }
      } else {
        final prevIndex = _playHistory.removeLast();
        if (prevIndex >= 0 && prevIndex < _queue.length) {
          _currentIndex = prevIndex;
        } else {
          await seek(Duration.zero);
          return;
        }
      }
    } else {
      if (!isOnline) {
        int targetIndex = -1;
        for (int step = 1; step < _queue.length; step++) {
          final idx = (_currentIndex - step + _queue.length) % _queue.length;
          if (_canPlayOffline(_queue[idx])) {
            targetIndex = idx;
            break;
          }
        }
        if (targetIndex != -1) {
          _currentIndex = targetIndex;
        } else if (_queue.length == 1 && _canPlayOffline(_queue[0])) {
          _currentIndex = 0;
        } else {
          _lastPlaybackError = 'network_error';
          notifyListeners();
          return;
        }
      } else {
        if (_currentIndex <= 0) {
          if (_repeatMode == PlaybackRepeatMode.off) {
            await seek(Duration.zero);
            return;
          }
          _currentIndex = _queue.length - 1;
        } else {
          _currentIndex = _currentIndex - 1;
        }
      }
    }
    await playTrack(_queue[_currentIndex]);
    _persistPlaybackState();
  }

  Future<void> stop() async {
    _persistTimer?.cancel();
    _storage.savePlaybackState(null);
    _stopPositionTimer();
    _retryTimer?.cancel();
    _retryCount = 0;
    _nextShuffleIndex = null;
    _prefetchedUri = null;
    _prefetchedForTrackId = null;
    _prefetchedTargetTrackId = null;
    _playHistory.clear();
    if (_useSpotify && _spotifyActive) {
      try { await _spotify.pause(); } catch (_) {}
    }
    _spotifyActive = false;
    _spotifyFallbackActive = false;
    await _service.stop();
    _foregroundService.stop();
    _currentTrack = null;
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    _position = pos;
    _crossfadeTriggered = false;

    if (_useSpotify && _spotifyActive && !_spotifyFallbackActive) {
      _spotifySyncPosition = pos;
      _spotifySyncTime = DateTime.now();
      notifyListeners();
      await _spotify.seekTo(pos.inMilliseconds);
    } else {
      notifyListeners();
      await _service.seek(pos);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _nextShuffleIndex = null;
    _prefetchedTargetTrackId = null;
    if (_currentTrack != null) {
      _prefetchNextTrack();
    }
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case PlaybackRepeatMode.off:
        _repeatMode = PlaybackRepeatMode.all;
        break;
      case PlaybackRepeatMode.all:
        _repeatMode = PlaybackRepeatMode.one;
        break;
      case PlaybackRepeatMode.one:
        _repeatMode = PlaybackRepeatMode.off;
        break;
    }
    _nextShuffleIndex = null;
    if (_currentIndex == _queue.length - 1) {
      _prefetchNextTrack();
    }
    notifyListeners();
  }

  void toggleLoop() => toggleRepeat();

  void setRepeatMode(PlaybackRepeatMode mode) {
    if (_repeatMode == mode) return;
    _repeatMode = mode;
    _nextShuffleIndex = null;
    if (_currentIndex == _queue.length - 1) {
      _prefetchNextTrack();
    }
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
    _nextShuffleIndex = null;
    _playHistory.clear();
    _prefetchNextTrack();
    _persistPlaybackState();
    notifyListeners();
  }

  void playNext(Track track) {
    if (_queue.any((t) => t.id == track.id)) return;
    final insertAt = _currentIndex + 1;
    final pos = insertAt < _queue.length ? insertAt : _queue.length;
    _queue.insert(pos, track);
    _shiftIndicesAfterInsert(pos, 1);
    _persistPlaybackState();
    notifyListeners();
  }

  void addToQueue(Track track) {
    if (_queue.any((t) => t.id == track.id)) return;
    _queue.add(track);
    _persistPlaybackState();
    notifyListeners();
  }

  void addAllToQueue(List<Track> tracks) {
    final existing = _queue.map((t) => t.id).toSet();
    final newTracks = tracks.where((t) => !existing.contains(t.id)).toList();
    if (newTracks.isEmpty) return;
    _queue.addAll(newTracks);
    _persistPlaybackState();
    notifyListeners();
  }

  void _shiftIndicesAfterInsert(int insertPos, int count) {
    if (_nextShuffleIndex != null && _nextShuffleIndex! >= insertPos) {
      _nextShuffleIndex = _nextShuffleIndex! + count;
    }
    for (int i = 0; i < _playHistory.length; i++) {
      if (_playHistory[i] >= insertPos) {
        _playHistory[i] += count;
      }
    }
  }

  /// Removes the track at [index] from the playback queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final wasCurrent = index == _currentIndex;
    _queue.removeAt(index);

    // Adjust or invalidate shuffle index
    if (_nextShuffleIndex != null) {
      if (_nextShuffleIndex == index) {
        _nextShuffleIndex = null;
      } else if (_nextShuffleIndex! > index) {
        _nextShuffleIndex = _nextShuffleIndex! - 1;
      }
    }

    // Adjust play history indices
    _playHistory.removeWhere((i) => i == index);
    for (int i = 0; i < _playHistory.length; i++) {
      if (_playHistory[i] > index) {
        _playHistory[i] -= 1;
      }
    }

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
      _prefetchNextTrack();
      notifyListeners();
    }
    _persistPlaybackState();
  }

  /// Clears the entire queue except for the currently playing track.
  void clearQueue() {
    _nextShuffleIndex = null;
    _prefetchedUri = null;
    _prefetchedForTrackId = null;
    _prefetchedTargetTrackId = null;
    _playHistory.clear();
    if (_currentTrack != null) {
      _queue = [_currentTrack!];
      _currentIndex = 0;
    } else {
      _queue = [];
      _currentIndex = -1;
    }
    _persistPlaybackState();
    notifyListeners();
  }

  @visibleForTesting
  Future<void> handleTrackCompletedForTesting() async {
    _completionHandled = false;
    _crossfadeTriggered = false;
    _lastPlayStart = DateTime.now().subtract(const Duration(seconds: 10));
    _handleTrackCompleted();
    await Future.delayed(Duration.zero);
  }

  void _handleTrackCompleted() {
    if (_completionHandled || _crossfadeTriggered) return;
    if (DateTime.now().difference(_lastPlayStart).inSeconds < 3) return;
    _completionHandled = true;

    if (_stopAfterCurrentTrack) {
      _stopAfterCurrentTrack = false;
      _sleepTimerDeadline = null;
      _sleepTimerRemaining = null;
      stop();
      return;
    }

    if (_repeatMode == PlaybackRepeatMode.one && _currentTrack != null) {
      playTrack(_currentTrack!);
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      next();
    } else {
      // PlaybackRepeatMode.off
      if (_isShuffle) {
        if (_playHistory.toSet().length >= _queue.length - 1 &&
            !_playHistory.contains(_currentIndex)) {
          stop();
        } else {
          next();
        }
      } else {
        if (_currentIndex + 1 < _queue.length) {
          next();
        } else {
          stop();
        }
      }
    }
  }

  void _checkCrossfade(Duration pos) {
    if (_repeatMode == PlaybackRepeatMode.one) return;
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered) return;
    if (_useSpotify && !_spotifyFallbackActive) return;
    if (_stopAfterCurrentTrack) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (pos.inSeconds < 2) return;

    final remaining = _duration - pos;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerCrossfade();
    }
  }

  @visibleForTesting
  bool get crossfadeTriggered => _crossfadeTriggered;

  @visibleForTesting
  void checkCrossfade(Duration pos) => _checkCrossfade(pos);

  Future<void> _triggerCrossfade() async {
    if (_queue.isEmpty || _crossfadeTriggered) return;

    int nextIdx;
    if (_isShuffle && _queue.length > 1) {
      if (_nextShuffleIndex != null &&
          _nextShuffleIndex! >= 0 &&
          _nextShuffleIndex! < _queue.length &&
          _nextShuffleIndex != _currentIndex) {
        nextIdx = _nextShuffleIndex!;
      } else {
        nextIdx = _pickSmartNext();
      }
      _nextShuffleIndex = null;
    } else if (_currentIndex + 1 < _queue.length) {
      nextIdx = _currentIndex + 1;
    } else if (_repeatMode == PlaybackRepeatMode.all && _queue.isNotEmpty) {
      nextIdx = 0;
    } else {
      return;
    }

    _addToPlayHistory(_currentIndex);
    _crossfadeTriggered = true;
    final nextTrack = _queue[nextIdx];
    if (_isShuffle) _recordShuffleHistory(nextTrack);
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
      final freshNext = await _withFreshPreview(nextTrack);
      if (gen != _playGeneration) return;
      await _service.crossfadeTo(freshNext, _crossfadeSeconds);
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    } catch (e) {
      debugPrint('[AudioProvider] Crossfade error, falling back to normal play: $e');
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
      try {
        await _service.playTrack(nextTrack);
      } catch (_) {}
    }
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (duration == null) {
      _sleepTimerDeadline = null;
      _sleepTimerRemaining = null;
      _stopAfterCurrentTrack = false;
      _sleepTimerOriginalMinutes = null;
      notifyListeners();
      return;
    }

    if (duration == Duration.zero) {
      _sleepTimerDeadline = null;
      _stopAfterCurrentTrack = true;
      _sleepTimerRemaining = null;
      _sleepTimerOriginalMinutes = 0;
      notifyListeners();
      return;
    }

    _sleepTimerDeadline = DateTime.now().add(duration);
    _sleepTimerRemaining = duration;
    _stopAfterCurrentTrack = false;
    _sleepTimerOriginalMinutes = duration.inMinutes;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      checkSleepTimer();
    });
  }

  void checkSleepTimer() {
    if (_sleepTimerDeadline == null) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      return;
    }
    final remaining = _sleepTimerDeadline!.difference(DateTime.now());
    if (remaining.inSeconds <= 0) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerDeadline = null;
      _sleepTimerRemaining = null;
      _stopAfterCurrentTrack = false;
      _sleepTimerOriginalMinutes = null;
      stop();
    } else {
      _sleepTimerRemaining = remaining;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _eventSub?.cancel();
    _stopPositionTimer();
    _retryTimer?.cancel();
    _sleepTimer?.cancel();
    _nativePlayer.dispose();
    _service.dispose();
    super.dispose();
  }
}
