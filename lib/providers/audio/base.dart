part of 'audio_provider.dart';

abstract class _AudioProviderBase extends ChangeNotifier
    with WidgetsBindingObserver {
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

  String? _prefetchedUri;
  String? _prefetchedForTrackId;
  String? _prefetchedTargetTrackId;
  int _prefetchGeneration = 0;

  bool _completionHandled = false;
  bool _crossfadeTriggered = false;
  int _crossfadeSeconds = 3;
  bool _autoMarkListened = false;
  bool _precacheWifiOnly = false;
  int _autoMarkedGeneration = -1;
  static const double _autoMarkThreshold = 0.8;
  DateTime _lastPlayStart = DateTime(2000);
  int _playGeneration = 0;

  Duration _spotifySyncPosition = Duration.zero;
  DateTime _spotifySyncTime = DateTime(2000);
  DateTime _lastPlayCommandTime = DateTime(2000);
  String? _currentSpotifyUri;

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
  Function(Track)? onListenedThreshold;
  Function(Track)? onPlayCounted;
  int _playCountedGeneration = -1;

  SongRadio? _radio;
  RadioStatus _radioStatus = RadioStatus.ready;
  RadioMode _radioModePref = RadioMode.balanced;
  Future<bool>? _radioTopUpFuture;
  static const int _radioLowWater = 4;
  static const int _radioMaxQueue = 150;
  static const String _radioModeKey = 'tsuki_radio_mode';

  bool _spotifyInterrupted = false;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

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
  int? get nextShuffleIndex => _q.nextShuffleIndex;
  bool get _online => _connectivityProvider?.isOnline ?? true;

  ConnectivityProvider? get connectivityProvider => _connectivityProvider;

  @visibleForTesting
  List<int> get playHistory => _q.history;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

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

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    notifyListeners();
    await _storage.saveCrossfadeSeconds(_crossfadeSeconds);
  }

  void setConnectivityProvider(ConnectivityProvider cp) {
    _connectivityProvider = cp;
  }

  // ---------------------------------------------------------------------------
  // Abstract methods implemented by mixins
  // ---------------------------------------------------------------------------

  // SpotifyPlaybackMixin
  void _initSpotify();
  Future<void> _initAudioSession();
  Future<void> _playViaSpotify(Track track);
  void _startPositionTimer();
  void _stopPositionTimer();
  Future<void> _spotifyPause();
  Future<void> _spotifyResume();
  Future<void> _spotifySeek(int ms);
  Future<void> _verifySpotifyResume();
  void _syncSpotifyPlaybackState();
  void _prefetchNextTrack();
  Future<void> updateSpotifyState();

  // PlaybackStateMixin
  void _attachMediaHandler(TsukiAudioHandler handler);
  void _syncMediaSession({bool force = false});
  void _syncHomeWidget();
  void _persistPlaybackState();
  Future<void> _restorePlaybackState();
  void _maybePersistPosition();

  // QueueMixin
  Future<void> next();
  Future<void> previous();
  void _handleTrackCompleted();

  // RadioMixin
  Future<bool> _radioTopUp({bool force = false, int count = 8});
  void _radioRegisterLeaving(Track incoming, {bool completed = false});
  Map<String, dynamic>? _radioSnapshot();

  // CrossfadeMixin
  void _checkCrossfade(Duration pos);
  void _checkSpotifyCrossfade();

  // SleepTimerMixin
  void checkSleepTimer();

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  _AudioProviderBase({
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

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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

  @override
  void notifyListeners() {
    _syncMediaSession();
    _syncHomeWidget();
    super.notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Listened-threshold checks
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void checkListenedThresholdForTesting() => _checkListenedThreshold();

  @visibleForTesting
  void checkPlayCountedForTesting() => _checkPlayCounted();

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

  // ---------------------------------------------------------------------------
  // Audio stream subscriptions
  // ---------------------------------------------------------------------------

  void _initSubscriptions() {
    _posSub = _service.positionStream.listen((pos) {
      _position = pos;
      _checkCrossfade(pos);
      _checkListenedThreshold();
      _checkPlayCounted();
      _maybePersistPosition();
    });
    _durSub = _service.durationStream.listen((dur) {
      _duration = dur ?? _duration;
    });
    _bufSub = _service.bufferedStream.listen((buf) {
      _bufferedPosition = buf;
    });
    _stateSub = _service.stateStream.listen((state) {
      final prev = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      _isBuffering = state == PlayerState.buffering;
      if (_isPlaying && !prev) {
        _lastPlayCommandTime = DateTime.now();
      }
      notifyListeners();
    });
    _eventSub = _service.eventStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Playback error handling
  // ---------------------------------------------------------------------------

  PlaybackError _classifyPlaybackError(Object error, Track track) {
    final msg = error.toString().toLowerCase();
    if (track.previewUrl.isEmpty) return PlaybackError.noPreview;
    if (msg.contains('socketexception') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('network')) {
      return PlaybackError.network;
    }
    if (msg.contains('format') || msg.contains('unsupported')) {
      return PlaybackError.formatUnsupported;
    }
    return PlaybackError.generic;
  }

  void _scheduleRetry(Track track) {
    if (_retryCount >= _maxPlaybackRetries) {
      debugPrint('[AudioProvider] Max retries reached for "${track.title}"');
      _retryCount = 0;
      return;
    }
    _retryCount++;
    final delay = Duration(seconds: _retryCount * 2);
    debugPrint('[AudioProvider] Scheduling retry #$_retryCount in ${delay.inSeconds}s');
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      if (_currentTrack?.id != track.id) return;
      _lastPlaybackError = null;
      _isBuffering = true;
      notifyListeners();
      try {
        final fresh = await _withFreshPreview(track, force: true);
        await _service.playTrack(fresh);
        _retryCount = 0;
      } catch (e) {
        _isBuffering = false;
        _lastPlaybackError = _classifyPlaybackError(e, track);
        notifyListeners();
        _scheduleRetry(track);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Core playback
  // ---------------------------------------------------------------------------

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    _lastPlaybackError = null;
    _retryTimer?.cancel();
    _retryCount = 0;
    _radioRegisterLeaving(track);

    if (newQueue != null) {
      _q.setQueue(newQueue);
      _q.select(newQueue.indexWhere((t) => t.id == track.id).clamp(0, newQueue.length - 1));
    } else if (!_q.isEmpty) {
      final idx = _q.tracks.indexWhere((t) => t.id == track.id);
      if (idx >= 0) {
        _q.select(idx);
      } else {
        _q.setQueue([track]);
        _q.select(0);
      }
    } else {
      _q.setQueue([track]);
      _q.select(0);
    }

    _currentTrack = track;
    _isPlaying = true;
    _isBuffering = true;
    _position = Duration.zero;
    _duration = Duration(
        seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;
    _crossfadeTriggered = false;

    notifyListeners();
    onTrackStarted?.call(track);

    if (_useSpotify && !_spotifyFallbackActive) {
      try {
        await _playViaSpotify(track);
        if (gen != _playGeneration) return;
      } catch (e) {
        debugPrint('[AudioProvider] Spotify play error: $e');
        if (gen != _playGeneration) return;
        _lastSpotifyError = SpotifyFallbackReason.openApp;
        _spotifyActive = false;
        _spotifyFallbackActive = true;
      }
    }

    if (!_useSpotify || _spotifyFallbackActive) {
      try {
        final freshTrack = await _withFreshPreview(track);
        if (gen != _playGeneration) return;
        await _service.playTrack(freshTrack);
        if (gen != _playGeneration) return;
        _isBuffering = false;
      } catch (e) {
        if (gen != _playGeneration) return;
        _isBuffering = false;
        _isPlaying = false;
        _lastPlaybackError = _classifyPlaybackError(e, track);
        _scheduleRetry(track);
      }
      notifyListeners();
    }

    _prefetchNextTrack();
    unawaited(_radioTopUp());
    _persistPlaybackState();
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
      try {
        await _spotifyPause();
      } catch (_) {}
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

  // ---------------------------------------------------------------------------
  // Preview refresh & precaching utilities
  // ---------------------------------------------------------------------------

  void _precache(Track track) {
    if (_precacheWifiOnly && (_connectivityProvider?.isMetered ?? false)) {
      return;
    }
    _withFreshPreview(track).then(AudioPrecacheService().precacheTrack);
  }

  Future<Track> _withFreshPreview(Track track, {bool force = false}) async {
    final url = track.previewUrl;
    if (url.isEmpty || !DeezerPreview.isDeezerUrl(url)) return track;
    if (AudioPrecacheService().getCachedFilePath(track.id) != null) {
      return track;
    }
    if (!force && !DeezerPreview.isExpired(url)) return track;

    final fresh =
        await DeezerApiService().getTrack(track.id, forceRefresh: true);
    if (fresh == null || fresh.previewUrl.isEmpty || fresh.previewUrl == url) {
      return track;
    }
    debugPrint(
        '[AudioProvider] Refreshed expired preview for "${track.title}"');
    final updated = track.copyWith(
      previewUrl: fresh.previewUrl,
      isrc: track.isrc ?? fresh.isrc,
    );
    _q.replaceTrack(updated);
    if (_currentTrack?.id == track.id) _currentTrack = updated;
    return updated;
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

  // ---------------------------------------------------------------------------
  // Init settings from storage
  // ---------------------------------------------------------------------------

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

  @visibleForTesting
  void setPositionForTesting(Duration pos) {
    _position = pos;
  }

  @visibleForTesting
  int? peekNextIndex() => _q.peekNext();

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

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
