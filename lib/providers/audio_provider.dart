import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/deezer_preview.dart';
import '../models/playback_error.dart';
import '../models/repeat_mode.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/audio_precache_service.dart';
import '../services/deezer_api_service.dart';
import '../services/media_session_handler.dart';
import '../services/playback_queue.dart';
import '../services/song_radio.dart';
import '../services/spotify_service.dart';
import '../services/spotify_web_player.dart';
import '../services/storage_service.dart';
import 'connectivity_provider.dart';

export '../models/playback_error.dart';
export '../models/repeat_mode.dart';
export '../services/song_radio.dart' show RadioMode, RadioReason, RadioSource;

enum RadioStatus { loading, ready, offline, exhausted }

class AudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayerService _service;
  final SpotifyService _spotify;
  final SpotifyNativePlayer _nativePlayer;
  TsukiAudioHandler? _mediaHandler;
  final StorageService _storage;
  ConnectivityProvider? _connectivityProvider;
  Timer? _persistTimer;

  @visibleForTesting
  Function(Track track)? onPrecacheTrackForTesting;

  Track? _currentTrack;
  final PlaybackQueue _q = PlaybackQueue();

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 30);
  Duration _bufferedPosition = Duration.zero;

  bool _useSpotify = false;
  bool _spotifyActive = false;
  bool _spotifyFallbackActive = false;
  SpotifyFallbackReason? _lastSpotifyError;
  PlaybackError? _lastPlaybackError;

  // Prefetch next track URI
  String? _prefetchedUri;
  String? _prefetchedForTrackId;
  String? _prefetchedTargetTrackId;
  int _prefetchGeneration = 0;

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

  /// Called once per play when it has been heard long enough to count.
  Function(Track)? onPlayCounted;
  int _playCountedGeneration = -1;

  // Song radio: keeps the queue topped up while active.
  SongRadio? _radio;
  RadioStatus _radioStatus = RadioStatus.ready;
  RadioMode _radioModePref = RadioMode.balanced;
  Future<bool>? _radioTopUpFuture;
  static const int _radioLowWater = 4;
  static const int _radioMaxQueue = 150;
  static const String _radioModeKey = 'tsuki_radio_mode';

  bool get isRadioActive => _radio != null;
  Track? get radioSeed => _radio?.seed;
  RadioMode get radioMode => _radio?.mode ?? _radioModePref;
  RadioStatus get radioStatus => _radioStatus;
  bool get radioUsesLastFm => _radio?.usesLastFm ?? false;
  RadioReason? radioReasonFor(String trackId) => _radio?.reasonFor(trackId);

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _q.tracks;
  int get currentIndex => _q.currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _q.isShuffle;
  PlaybackRepeatMode get repeatMode => _q.repeatMode;
  bool get isLoop => _q.repeatMode != PlaybackRepeatMode.off;
  bool get isRepeatAll => _q.repeatMode == PlaybackRepeatMode.all;
  bool get isRepeatOne => _q.repeatMode == PlaybackRepeatMode.one;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  bool get useSpotify => _useSpotify;
  bool get spotifyFallbackActive => _spotifyFallbackActive;
  SpotifyService get spotify => _spotify;
  SpotifyFallbackReason? get lastSpotifyError => _lastSpotifyError;
  PlaybackError? get lastPlaybackError => _lastPlaybackError;
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

  void _attachMediaHandler(TsukiAudioHandler handler) {
    _mediaHandler = handler;
    handler.onPlay = () async {
      if (!_isPlaying) await togglePlay();
    };
    handler.onPause = () async {
      if (_isPlaying) await togglePlay();
    };
    handler.onStop = stop;
    handler.onSkipToNext = next;
    handler.onSkipToPrevious = previous;
    handler.onSeek = (pos) => seek(pos);
  }

  // Last state pushed to the media session. Position is not part of the key:
  // the system extrapolates it from updatePosition + updateTime, so pushing
  // on every tick would only waste work.
  String? _mediaItemKey;
  String? _mediaStateKey;

  @override
  void notifyListeners() {
    _syncMediaSession();
    super.notifyListeners();
  }

  void _syncMediaSession({bool force = false}) {
    final handler = _mediaHandler;
    if (handler == null) return;
    final track = _currentTrack;

    final itemKey = track == null
        ? null
        : '${track.id}|${track.title}|${_duration.inSeconds}';
    if (itemKey != _mediaItemKey) {
      _mediaItemKey = itemKey;
      handler.mediaItem.add(track == null
          ? null
          : MediaItem(
              id: track.id,
              title: track.title,
              artist: track.fullArtistName,
              album: track.albumTitle,
              artUri: track.coverUrl.isNotEmpty
                  ? Uri.tryParse(track.coverUrl)
                  : null,
              duration: _duration,
            ));
    }

    final processing = track == null
        ? AudioProcessingState.idle
        : (_isBuffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready);
    final stateKey = '$processing|$_isPlaying|$itemKey';
    if (!force && stateKey == _mediaStateKey) return;
    _mediaStateKey = stateKey;
    handler.playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processing,
      playing: _isPlaying,
      updatePosition: _position,
      bufferedPosition: _bufferedPosition,
      speed: 1.0,
    ));
  }

  @visibleForTesting
  void checkListenedThresholdForTesting() => _checkListenedThreshold();

  @visibleForTesting
  void checkPlayCountedForTesting() => _checkPlayCounted();

  /// A play counts once per play past half the track (30 s at most), so
  /// quick skips and previews abandoned early don't inflate stats.
  void _checkPlayCounted() {
    if (_playCountedGeneration == _playGeneration) return;
    final track = _currentTrack;
    if (track == null || _duration <= Duration.zero) return;
    final half = _duration.inMilliseconds ~/ 2;
    final needed = half < 30000 ? half : 30000;
    if (_position.inMilliseconds < needed) return;
    _playCountedGeneration = _playGeneration;
    onPlayCounted?.call(track);
  }

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
  int? get nextShuffleIndex => _q.nextShuffleIndex;

  @visibleForTesting
  List<int> get playHistory => _q.history;

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
    if (_q.isEmpty) return;
    for (var i = 1; i <= count; i++) {
      final idx = (_q.currentIndex + i) % _q.length;
      if (idx != _q.currentIndex) {
        final track = _q.tracks[idx];
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
    TsukiAudioHandler? mediaHandler,
    SpotifyService? spotifyService,
    SpotifyNativePlayer? nativePlayer,
  })  : _service = service ?? AudioPlayerService(),
        _storage = storage ?? StorageService(),
        _spotify = spotifyService ?? SpotifyService(),
        _nativePlayer = nativePlayer ?? SpotifyNativePlayer(),
        _connectivityProvider = connectivityProvider {
    if (mediaHandler != null) _attachMediaHandler(mediaHandler);
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
      if (_q.current == null) {
        await _storage.savePlaybackState(null);
        return;
      }
      await _storage.savePlaybackState(
        _q.tracks,
        _q.currentIndex,
        _position.inMilliseconds,
        _radioSnapshot(),
      );
    });
  }

  Map<String, dynamic>? _radioSnapshot() =>
      _radio?.toJson(keepReasonsFor: _q.tracks.map((t) => t.id));

  @visibleForTesting
  void persistPlaybackStateNowForTesting() {
    _persistTimer?.cancel();
    if (_q.current == null) {
      _storage.savePlaybackState(null);
      return;
    }
    _storage.savePlaybackState(
      _q.tracks,
      _q.currentIndex,
      _position.inMilliseconds,
      _radioSnapshot(),
    );
  }

  Future<void> _restorePlaybackState() async {
    try {
      final state = await _storage.getPlaybackState();
      if (state == null) return;

      if (_currentTrack != null || !_q.isEmpty || _isPlaying) return;

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

      _q.restore(restoredQueue, restoredIndex);
      _currentTrack = restoredTrack;
      _position = Duration(milliseconds: posMs);
      _duration = Duration(
          seconds: restoredTrack.durationSeconds > 0
              ? restoredTrack.durationSeconds
              : 30);
      _isPlaying = false;
      _isBuffering = false;

      final rawRadio = state['radio'];
      if (rawRadio is Map) {
        final radio = SongRadio.fromJson(Map<String, dynamic>.from(rawRadio));
        if (radio != null) {
          radio.markQueued(restoredQueue);
          _radio = radio;
          _radioModePref = radio.mode;
          _radioStatus = RadioStatus.ready;
        }
      }

      _prefetchNextTrack();
      notifyListeners();
      // Make sure the restored radio has songs lined up before they're due.
      if (_radio != null) unawaited(_radioTopUp());
      debugPrint('[AudioProvider] Restored playback state: "${restoredTrack.title}" at ${posMs}ms (${_q.length} tracks in queue${_radio != null ? ', radio on' : ''})');
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
            _spotifyPause();
            _isPlaying = false;
            _stopPositionTimer();
            _spotifyInterrupted = true;
            notifyListeners();
          }
        } else {
          if (_spotifyInterrupted) {
            _spotifyInterrupted = false;
            _spotifyResume().then((_) {
              if (!_spotifyActive || !_isPlaying) return;
              _lastPlayCommandTime = DateTime.now();
              unawaited(_verifySpotifyResume());
            });
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
          _spotifyPause();
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
    _nativePlayer.onStateChanged = (pos, dur, paused) {
      if (!_spotifyActive) return;
      if (_nativePlayer.lastTrackUri != _currentSpotifyUri) return;
      _spotifySyncPosition = Duration(milliseconds: pos);
      _spotifySyncTime = DateTime.now();
      _position = _spotifySyncPosition;
      if (dur > 0) _duration = Duration(milliseconds: dur);
      if (_isBuffering && !paused) {
        _isBuffering = false;
        _isPlaying = true;
        _lastPlayCommandTime = DateTime.now();
        _startPositionTimer();
      }
      if (!_isBuffering && paused == _isPlaying) {
        _isPlaying = !paused;
        if (_isPlaying) {
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }
      }
      notifyListeners();
    };

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

      final hasRealTimeState = _nativePlayer.isConnected;
      final pollInterval = hasRealTimeState ? 60 : 15;
      final pausePollInterval = hasRealTimeState ? 30 : 5;

      if (_isPlaying) {
        final elapsed = DateTime.now().difference(_spotifySyncTime);
        _position = _spotifySyncPosition + elapsed;
        if (_position >= _duration && _duration > Duration.zero) {
          _stopPositionTimer();
          _handleTrackCompleted();
        } else {
          _maybePersistPosition();
          _checkListenedThreshold();
          _checkPlayCounted();
          _checkSpotifyCrossfade();
          notifyListeners();
          if (_spotifyPollTick % pollInterval == 0) {
            _syncSpotifyPlaybackState();
          }
        }
      } else if (_currentTrack != null) {
        if (_spotifyPollTick % pausePollInterval == 0) {
          _syncSpotifyPlaybackState();
        }
      }
    });
  }

  Future<void> _syncSpotifyPlaybackState() async {
    try {
      if (_spotifyPollTick % 300 == 0 && _spotifyPollTick > 0) {
        await _spotify.refreshProfile();
        if (!_spotify.isPremium) {
          debugPrint('[AudioProvider] Spotify Premium lost, falling back to preview');
          await _fallbackFromSpotify();
          return;
        }
      }

      final state = await _spotify.getPlaybackState();
      if (!_spotifyActive || _completionHandled) return;
      if (state == null) {
        // No Spotify session at all (app closed or frozen): stop pretending
        // to play, outside the grace period after a play command.
        final sincePlay = DateTime.now().difference(_lastPlayCommandTime);
        final nativePlaying = _currentSpotifyUri != null &&
            _nativePlayer.isPlayingUri(_currentSpotifyUri!);
        if (_isPlaying && !nativePlaying && sincePlay.inSeconds >= 10) {
          debugPrint('[AudioProvider] Spotify session gone, marking paused');
          _isPlaying = false;
          notifyListeners();
        }
        return;
      }

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

      if (durationMs > 0) {
        _duration = Duration(milliseconds: durationMs);
      }

      if (!_nativePlayer.isConnected) {
        _spotifySyncPosition = Duration(milliseconds: progressMs);
        _spotifySyncTime = DateTime.now();
        _position = _spotifySyncPosition;
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

  Future<void> _spotifyPause() async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.pause();
        return;
      } catch (e) {
        debugPrint('[AudioProvider] App Remote pause failed, trying Web API: $e');
      }
    }
    await _spotify.pause();
  }

  Future<void> _spotifyResume() async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.resume();
        return;
      } catch (e) {
        debugPrint('[AudioProvider] App Remote resume failed, trying Web API: $e');
      }
    }
    await _spotify.resume();
  }

  Future<void> _spotifySeek(int positionMs) async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.seekTo(positionMs);
        return;
      } catch (e) {
        debugPrint('[AudioProvider] App Remote seek failed, trying Web API: $e');
      }
    }
    await _spotify.seekTo(positionMs);
  }

  void _initSubscriptions() {
    _posSub = _service.positionStream.listen((pos) {
      if (!_spotifyActive) {
        _position = pos;
        _checkCrossfade(pos);
        if (_isPlaying) {
          _maybePersistPosition();
          _checkListenedThreshold();
          _checkPlayCounted();
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

  PlaybackError _classifyPlaybackError(Object error, [Track? track]) {
    final errStr = error.toString().toLowerCase();

    // 1. No preview available
    if (track != null && track.previewUrl.trim().isEmpty) {
      return PlaybackError.noPreview;
    }
    if (errStr.contains('preview is unavailable') ||
        errStr.contains('no preview') ||
        errStr.contains('preview_unavailable')) {
      return PlaybackError.noPreview;
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
      return PlaybackError.network;
    }

    // 3. Format unsupported
    if (errStr.contains('format') ||
        errStr.contains('unsupported') ||
        errStr.contains('codec') ||
        errStr.contains('decode') ||
        errStr.contains('demux') ||
        errStr.contains('extractor')) {
      return PlaybackError.formatUnsupported;
    }

    return PlaybackError.generic;
  }

  @visibleForTesting
  PlaybackError classifyPlaybackError(Object error, [Track? track]) =>
      _classifyPlaybackError(error, track);

  void _handlePlaybackError(Object error) {
    if ((_useSpotify && _spotifyActive && !_spotifyFallbackActive) || _currentTrack == null) return;
    if (_retryTimer?.isActive == true) return;

    final classified = _classifyPlaybackError(error, _currentTrack);
    // Non-transient errors: abort immediate retry and report specific error
    if (classified == PlaybackError.noPreview || classified == PlaybackError.formatUnsupported) {
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
    // Playing an album/playlist replaces the radio; picking within the
    // queue keeps it and teaches it whether the last song was skipped.
    if (newQueue != null) _radio = null;
    _radioRegisterLeaving(track);
    _q.select(track, newQueue: newQueue);
    if (newQueue != null && newQueue.isNotEmpty) _prefetchUpcoming();

    _retryTimer?.cancel();
    _retryCount = 0;
    _currentTrack = track;
    _position = Duration.zero;
    _completionHandled = false;
    _crossfadeTriggered = false;
    _lastPlayStart = DateTime.now();
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null) {
      unawaited(SemanticsService.sendAnnouncement(view, '${track.title}, ${track.fullArtistName}', TextDirection.ltr));
    }
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
        _lastPlaybackError = PlaybackError.network;
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
      _persistPlaybackState();
      _prefetchNextTrack();
      unawaited(_radioTopUp());
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
      _lastSpotifyError = SpotifyFallbackReason.trackUnavailable;
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    debugPrint('Spotify: found URI=$uri');
    _currentSpotifyUri = uri;

    // Fast path: App Remote is already connected (warm-up or previous play),
    // skip the Web API round-trips that fail on phones where the Spotify app
    // is frozen/backgrounded.
    if (_nativePlayer.isConnected) {
      debugPrint('Spotify: App Remote connected, playing directly...');
      final ok = await _nativePlayer.playUri(uri);
      if (gen != _playGeneration) return;
      if (ok) {
        debugPrint('Spotify: App Remote fast-path succeeded');
        _spotifyActive = true;
        _spotifyFallbackActive = false;
        _isPlaying = false;
        _isBuffering = true;
        _position = Duration.zero;
        _lastPlayCommandTime = DateTime.now();
        notifyListeners();
        _prefetchNextTrack();
        unawaited(_verifySpotifyPlayback(gen, uri, track));
        return;
      }
      debugPrint('Spotify: App Remote fast-path failed, falling through to Web API');
    }

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
      // No usable Web API device (Spotify app closed or frozen). App Remote
      // launches the Spotify app and plays in it directly.
      debugPrint('Spotify: Web API exhausted, playing through App Remote...');
      try {
        final token = _spotify.accessToken;
        if (token != null) {
          final connected = await _nativePlayer.connect(accessToken: token);
          if (gen != _playGeneration) return;
          if (connected) {
            played = await _nativePlayer.playUri(uri);
            if (gen != _playGeneration) return;
            debugPrint('Spotify: App Remote play result=$played');
          }
        }
      } catch (e) {
        debugPrint('Spotify: App Remote error: $e');
      }
    }

    if (!played) {
      debugPrint('Spotify: all play attempts failed, falling back to preview');
      _lastSpotifyError = SpotifyFallbackReason.openApp;
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      await _playPreviewInsteadOfSpotify(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

    _spotifyActive = true;
    _spotifyFallbackActive = false;
    _isPlaying = false;
    _isBuffering = true;
    _position = Duration.zero;
    _lastPlayCommandTime = DateTime.now();
    notifyListeners();
    _prefetchNextTrack();
    unawaited(_verifySpotifyPlayback(gen, uri, track));
  }

  /// The Web API can accept a play command (204) for a Spotify device whose
  /// app the system has frozen in the background (common on Honor/Huawei):
  /// nothing plays and /me/player stays empty. Confirm playback a few seconds
  /// in; if it didn't start, wake Spotify through App Remote and play there,
  /// and if that fails too, fall back to the Deezer preview.
  Future<void> _verifySpotifyPlayback(int gen, String uri, Track track) async {
    if (await _spotifyConfirmsPlaying(gen, uri)) return;

    debugPrint('[SpotifyCheck] Not playing, waking Spotify via App Remote');
    final token = _spotify.accessToken;
    if (token != null) {
      final connected = await _nativePlayer.connect(accessToken: token);
      if (gen != _playGeneration) return;
      if (connected && await _nativePlayer.playUri(uri)) {
        final now = DateTime.now();
        _position = Duration.zero;
        _spotifySyncPosition = Duration.zero;
        _spotifySyncTime = now;
        _lastPlayCommandTime = now;
        if (await _spotifyConfirmsPlaying(gen, uri)) return;
      }
    }
    if (gen != _playGeneration || !_spotifyActive) return;

    debugPrint('[SpotifyCheck] Spotify did not start, falling back to preview');
    _lastSpotifyError = SpotifyFallbackReason.openApp;
    _spotifyActive = false;
    _spotifyFallbackActive = true;
    _stopPositionTimer();
    _position = Duration.zero;
    _isBuffering = true;
    notifyListeners();
    try {
      await _playPreviewInsteadOfSpotify(await _withFreshPreview(track));
    } catch (e) {
      if (gen != _playGeneration) return;
      _lastPlaybackError = _classifyPlaybackError(e, track);
    }
    if (gen != _playGeneration) return;
    _isBuffering = false;
    notifyListeners();
  }

  /// Plays the preview after Spotify failed. A Spotify app we just woke can
  /// take audio focus and immediately pause the preview, so stop it first.
  Future<void> _playPreviewInsteadOfSpotify(Track track) async {
    await _nativePlayer.pause();
    await _nativePlayer.disconnect();
    await _service.playTrack(track);
  }

  Future<void> _fallbackFromSpotify() async {
    _useSpotify = false;
    _spotifyActive = false;
    _spotifyFallbackActive = true;
    _stopPositionTimer();
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null) {
      unawaited(SemanticsService.sendAnnouncement(view, 'Spotify Premium not available, switching to preview', TextDirection.ltr));
    }
    await _nativePlayer.pause();
    await _nativePlayer.disconnect();

    final track = _currentTrack;
    if (track != null && _isPlaying) {
      _isBuffering = true;
      notifyListeners();
      try {
        final fresh = await _withFreshPreview(track);
        await _service.playTrack(fresh);
        _isBuffering = false;
      } catch (e) {
        _isBuffering = false;
        _isPlaying = false;
        _lastPlaybackError = _classifyPlaybackError(e, track);
      }
    }
    notifyListeners();
  }

  /// Waits a moment and asks Spotify whether [uri] is really playing.
  /// Returns true too when there is nothing left to check (track changed,
  /// Spotify no longer in use, or the user paused meanwhile).
  Future<bool> _spotifyConfirmsPlaying(int gen, String uri) async {
    await Future.delayed(const Duration(seconds: 3));
    if (gen != _playGeneration || !_spotifyActive) return true;
    if (_nativePlayer.isPlayingUri(uri)) {
      debugPrint('[SpotifyCheck] Playing (App Remote)');
      _onSpotifyConfirmed(0);
      return true;
    }
    final state = await _spotify.getPlaybackState();
    if (gen != _playGeneration || !_spotifyActive) return true;
    if (state == null) {
      debugPrint('[SpotifyCheck] No active Spotify session');
      return false;
    }
    final device = state['device'] as Map<String, dynamic>?;
    final item = state['item'] as Map<String, dynamic>?;
    final linked = item?['linked_from'] as Map<String, dynamic>?;
    final progressMs = state['progress_ms'] as int? ?? 0;
    debugPrint('[SpotifyCheck] is_playing=${state['is_playing']} '
        'progress_ms=$progressMs item=${item?['uri']} '
        'device=${device?['name']} volume=${device?['volume_percent']}');
    if (device?['volume_percent'] == 0) {
      debugPrint('[SpotifyCheck] Spotify device volume is 0%: playback is silent');
    }
    final confirmed = state['is_playing'] == true &&
        (item?['uri'] == uri || linked?['uri'] == uri);
    if (confirmed) {
      final durationMs = item?['duration_ms'] as int? ?? 0;
      if (durationMs > 0) _duration = Duration(milliseconds: durationMs);
      _onSpotifyConfirmed(progressMs);
    }
    return confirmed;
  }

  void _onSpotifyConfirmed(int progressMs) {
    if (_isPlaying && !_isBuffering) return;
    _isBuffering = false;
    _isPlaying = true;
    _spotifySyncPosition = Duration(milliseconds: progressMs);
    _spotifySyncTime = DateTime.now();
    _lastPlayCommandTime = DateTime.now();
    _startPositionTimer();
    notifyListeners();
  }


  Future<void> _verifySpotifyResume() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!_spotifyActive || !_isPlaying) return;
    if (_nativePlayer.isConnected &&
        _currentSpotifyUri != null &&
        _nativePlayer.isPlayingUri(_currentSpotifyUri!)) {
      return;
    }
    final state = await _spotify.getPlaybackState();
    if (!_spotifyActive || !_isPlaying) return;
    if (state != null && state['is_playing'] == true) return;
    debugPrint('[AudioProvider] Spotify did not resume after interruption, marking paused');
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
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
    _q.replaceTrack(updated);
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

  @visibleForTesting
  int? peekNextIndex() => _q.peekNext();

  void _prefetchNextTrack() {
    final nextIdx = _q.peekNext();
    if (nextIdx == null || nextIdx < 0 || nextIdx >= _q.length) return;

    final nextTrack = _q.tracks[nextIdx];

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
    if (_currentTrack == null && !_q.isEmpty) {
      await playTrack(_q.tracks.first);
      return;
    }

    if (_useSpotify && _spotifyActive && !_spotifyFallbackActive) {
      if (_isPlaying) {
        await _spotifyPause();
        _isPlaying = false;
        _stopPositionTimer();
      } else {
        await _spotifyResume();
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

  bool get _online => _connectivityProvider?.isOnline ?? true;

  /// Plays the result of a queue move, or reports why nothing can play.
  Future<void> _applyStep(QueueStep step) async {
    switch (step.kind) {
      case QueueStepKind.play:
        await playTrack(_q.tracks[step.index]);
        _persistPlaybackState();
      case QueueStepKind.seekToStart:
        await seek(Duration.zero);
      case QueueStepKind.unavailable:
        if (_q.isEmpty) return;
        _lastPlaybackError = PlaybackError.network;
        notifyListeners();
    }
  }

  Future<void> next() =>
      _applyStep(_q.next(online: _online, canPlay: _canPlayOffline));
  Future<void> previous() => _applyStep(_q.previous(
        position: _position,
        online: _online,
        canPlay: _canPlayOffline,
      ));
  Future<void> stop() async {
    _persistTimer?.cancel();
    unawaited(_storage.savePlaybackState(null));
    _stopPositionTimer();
    _retryTimer?.cancel();
    _retryCount = 0;
    _q.resetNavigation();
    _prefetchedUri = null;
    _prefetchedForTrackId = null;
    _prefetchedTargetTrackId = null;
    if (_useSpotify && _spotifyActive) {
      try { await _spotifyPause(); } catch (_) {}
    }
    _spotifyActive = false;
    _spotifyFallbackActive = false;
    await _service.stop();
    _currentTrack = null;
    _isPlaying = false;
    _isBuffering = false;
    _position = Duration.zero;
    _radio = null;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    _position = pos;
    _crossfadeTriggered = false;
    _syncMediaSession(force: true);

    if (_useSpotify && _spotifyActive && !_spotifyFallbackActive) {
      _spotifySyncPosition = pos;
      _spotifySyncTime = DateTime.now();
      notifyListeners();
      await _spotifySeek(pos.inMilliseconds);
    } else {
      notifyListeners();
      await _service.seek(pos);
    }
  }

  void toggleShuffle() {
    _q.toggleShuffle();
    _prefetchedTargetTrackId = null;
    if (_currentTrack != null) {
      _prefetchNextTrack();
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _q.cycleRepeatMode();
    if (_q.isAtEnd) _prefetchNextTrack();
    notifyListeners();
  }
  void toggleLoop() => toggleRepeat();

  void setRepeatMode(PlaybackRepeatMode mode) {
    if (_q.repeatMode == mode) return;
    _q.setRepeatMode(mode);
    if (_q.isAtEnd) _prefetchNextTrack();
    notifyListeners();
  }
  /// Reorders the playback queue from [oldIndex] to [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _q.length) return;
    if (newIndex < 0 || newIndex >= _q.length) return;
    _q.reorder(oldIndex, newIndex);
    _prefetchNextTrack();
    _persistPlaybackState();
    notifyListeners();
  }
  void playNext(Track track) {
    if (!_q.insertNext(track)) return;
    _persistPlaybackState();
    notifyListeners();
  }
  void addToQueue(Track track) => addAllToQueue([track]);
  void addAllToQueue(List<Track> tracks) {
    if (_q.append(tracks) == 0) return;
    _persistPlaybackState();
    notifyListeners();
  }
  /// Removes the track at [index] from the playback queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _q.length) return;
    final wasCurrent = _q.removeAt(index);

    if (_q.isEmpty) {
      stop();
      return;
    }

    if (wasCurrent) {
      playTrack(_q.tracks[_q.currentIndex]);
    } else {
      _prefetchNextTrack();
      notifyListeners();
    }
    _persistPlaybackState();
  }
  /// Clears the entire queue except for the currently playing track.
  void clearQueue() {
    _prefetchedUri = null;
    _prefetchedForTrackId = null;
    _prefetchedTargetTrackId = null;
    _q.clear(keep: _currentTrack);
    _persistPlaybackState();
    notifyListeners();
    // A radio never runs dry: clearing it just means "fresh picks, please".
    unawaited(_radioTopUp());
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

    if (_q.repeatMode == PlaybackRepeatMode.one && _currentTrack != null) {
      playTrack(_currentTrack!);
    } else if (_q.repeatMode == PlaybackRepeatMode.all) {
      next();
    } else if (_q.shouldStopAtEnd()) {
      if (_radio != null) {
        // Refill failed to stay ahead (e.g. slow network): wait for it.
        unawaited(
            _radioTopUp(force: true).then((added) => added ? next() : stop()));
      } else {
        stop();
      }
    } else {
      next();
    }
  }

  // ---------------------------------------------------------------------------
  // Song radio
  // ---------------------------------------------------------------------------

  /// Starts an endless radio from [seed]. Returns false when no similar
  /// songs could be found at all.
  Future<bool> startRadio(Track seed) async {
    await _loadRadioModePref();
    final radio = SongRadio(seed: seed, mode: _radioModePref);
    _radioTopUpFuture = null;
    _radioStatus = RadioStatus.loading;

    if (_currentTrack?.id == seed.id) {
      // Keep the song playing; the radio replaces what comes after it.
      _radio = radio;
      _prefetchedTargetTrackId = null;
      _q.clear(keep: _currentTrack);
      _persistPlaybackState();
      notifyListeners();
    } else {
      // Assigned after playTrack's synchronous start, so the new radio
      // doesn't learn from the unrelated song being replaced.
      final playing = playTrack(seed, newQueue: [seed]);
      _radio = radio;
      unawaited(playing);
    }

    final added = await _radioTopUp(force: true, count: 10);
    if (!added && identical(_radio, radio)) {
      _radio = null;
      _persistPlaybackState();
      notifyListeners();
    }
    return added;
  }

  void stopRadio() {
    if (_radio == null) return;
    _radio = null;
    _persistPlaybackState();
    notifyListeners();
  }

  Future<void> setRadioMode(RadioMode mode) async {
    _radioModePref = mode;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setInt(_radioModeKey, mode.index))
        .catchError((_) => false));
    final radio = _radio;
    if (radio == null || radio.mode == mode) {
      notifyListeners();
      return;
    }
    radio.setMode(mode);
    _persistPlaybackState();
    await _radioReplaceUpcoming(keep: 1);
  }

  /// Steers the radio toward the current song.
  Future<void> radioMoreLikeThis() async {
    final radio = _radio;
    final track = _currentTrack;
    if (radio == null || track == null) return;
    radio.moreLikeThis(track);
    await _radioReplaceUpcoming(keep: 1);
  }

  /// Bans the current artist from this radio and skips the song.
  Future<void> radioLessLikeThis() async {
    final radio = _radio;
    final track = _currentTrack;
    if (radio == null || track == null) return;
    radio.lessLikeThis(track);
    if (!_q.isShuffle) {
      for (var i = _q.length - 1; i > _q.currentIndex; i--) {
        if (radio.isBanned(_q.tracks[i])) _q.removeAt(i);
      }
    }
    _prefetchedTargetTrackId = null;
    await _radioTopUp(force: true);
    await next();
  }

  Future<void> _loadRadioModePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final i = prefs.getInt(_radioModeKey);
      if (i != null && i >= 0 && i < RadioMode.values.length) {
        _radioModePref = RadioMode.values[i];
      }
    } catch (_) {}
  }

  /// Teaches the radio how much of the outgoing song was heard.
  void _radioRegisterLeaving(Track incoming, {bool completed = false}) {
    final radio = _radio;
    final leaving = _currentTrack;
    if (radio == null || leaving == null || leaving.id == incoming.id) return;
    final total = _duration.inMilliseconds;
    final fraction = completed
        ? 1.0
        : (total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0);
    radio.registerPlayed(leaving, fraction);
  }

  int _radioRemaining() {
    if (_q.isShuffle) {
      final heard = {..._q.history, _q.currentIndex};
      return _q.length - heard.length;
    }
    return _q.length - _q.currentIndex - 1;
  }

  /// Single-flight refill: concurrent callers share the same request.
  Future<bool> _radioTopUp({bool force = false, int count = 8}) {
    if (_radio == null) return Future.value(false);
    if (!force && _radioRemaining() >= _radioLowWater) return Future.value(true);
    return _radioTopUpFuture ??=
        _doRadioTopUp(count).whenComplete(() => _radioTopUpFuture = null);
  }

  Future<bool> _doRadioTopUp(int count) async {
    final radio = _radio;
    if (radio == null) return false;
    _radioStatus = RadioStatus.loading;
    notifyListeners();

    List<Track> batch;
    try {
      batch = await radio.nextBatch(count: count);
    } catch (e) {
      debugPrint('[AudioProvider] radio refill failed: $e');
      batch = const [];
    }
    if (!identical(_radio, radio)) return false;

    final added = _q.append(batch);
    _trimRadioHistory();
    _radioStatus = added > 0
        ? RadioStatus.ready
        : (_online ? RadioStatus.exhausted : RadioStatus.offline);
    if (added > 0) {
      _prefetchNextTrack();
      _persistPlaybackState();
    }
    notifyListeners();
    return added > 0;
  }

  /// Endless queues would grow forever: forget most of what was played.
  void _trimRadioHistory() {
    if (_q.isShuffle || _q.length <= _radioMaxQueue) return;
    final drop = _q.currentIndex - 30;
    if (drop > 0) _q.dropBefore(drop);
  }

  /// Swaps the radio's upcoming picks for fresh ones (mode change, "more
  /// like this"), keeping the next [keep] songs and anything the user queued.
  Future<void> _radioReplaceUpcoming({required int keep}) async {
    final radio = _radio;
    if (radio == null) return;
    if (!_q.isShuffle) {
      final firstReplaceable = _q.currentIndex + 1 + keep;
      for (var i = _q.length - 1; i >= firstReplaceable; i--) {
        final reason = radio.reasonFor(_q.tracks[i].id);
        if (reason != null && reason.source != RadioSource.seed) _q.removeAt(i);
      }
    }
    _prefetchedTargetTrackId = null;
    notifyListeners();
    await _radioTopUp(force: true);
  }

  void _checkCrossfade(Duration pos) {
    if (_q.repeatMode == PlaybackRepeatMode.one) return;
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

  void _checkSpotifyCrossfade() {
    if (_q.repeatMode == PlaybackRepeatMode.one) return;
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered) return;
    if (_stopAfterCurrentTrack) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (_position.inSeconds < 2) return;

    final remaining = _duration - _position;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerSpotifyCrossfade();
    }
  }

  Future<void> _triggerSpotifyCrossfade() async {
    if (_q.isEmpty || _crossfadeTriggered) return;

    final nextIdx = _q.advanceForCrossfade();
    if (nextIdx == null) return;

    _crossfadeTriggered = true;
    final nextTrack = _q.tracks[nextIdx];
    debugPrint('[AudioProvider] Spotify crossfade to "${nextTrack.title}" (${_crossfadeSeconds}s before end)');

    _radioRegisterLeaving(nextTrack, completed: true);
    _currentTrack = nextTrack;
    _position = Duration.zero;
    _duration = Duration(
        seconds: nextTrack.durationSeconds > 0 ? nextTrack.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;

    notifyListeners();
    onTrackStarted?.call(nextTrack);
    _prefetchNextTrack();
    unawaited(_radioTopUp());

    try {
      await _playViaSpotify(nextTrack);
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    } catch (e) {
      debugPrint('[AudioProvider] Spotify crossfade error: $e');
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    }
  }

  @visibleForTesting
  bool get crossfadeTriggered => _crossfadeTriggered;

  @visibleForTesting
  void checkCrossfade(Duration pos) => _checkCrossfade(pos);

  Future<void> _triggerCrossfade() async {
    if (_q.isEmpty || _crossfadeTriggered) return;

    final nextIdx = _q.advanceForCrossfade();
    if (nextIdx == null) return;

    _crossfadeTriggered = true;
    final nextTrack = _q.tracks[nextIdx];
    _radioRegisterLeaving(nextTrack, completed: true);
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
    unawaited(_radioTopUp());

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
