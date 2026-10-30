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
import '../services/bpm_flow.dart';
import '../services/deezer_api_service.dart';
import '../services/home_widget_service.dart';
import '../services/media_session_handler.dart';
import '../services/playback_queue.dart';
import '../services/spotify_service.dart';
import '../services/spotify_web_player.dart';
import '../services/storage_service.dart';
import 'audio_radio_controller.dart';
import 'audio_sleep_timer.dart';
import 'connectivity_provider.dart';

export '../models/playback_error.dart';
export '../models/repeat_mode.dart';
export 'audio_radio_controller.dart';

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
  // Previews downloaded ahead of the current song, so the next ones play
  // without a connection (metro, plane) and without buffering.
  static const int _precacheAhead = 5;
  int _precacheGeneration = 0;

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
  // The market version Spotify actually plays when it relinks that URI.
  String? _linkedSpotifyUri;
  // Spotify moved on to a track we didn't ask for; resuming must replay ours.
  bool _spotifyTookOver = false;
  // Our next songs, handed to Spotify along with the current one, in play
  // order. Spotify plays them by itself, so the queue goes on even when
  // Android freezes or kills Tsuki in the background.
  List<({String trackId, String uri})> _spotifyAhead = const [];
  static const int _spotifyAheadMax = 8;

  late final SleepTimerController _sleepCtrl;

  VoidCallback? get onSleepTimerFinished => _sleepCtrl.onFinished;
  set onSleepTimerFinished(VoidCallback? cb) => _sleepCtrl.onFinished = cb;

  // Ambient-only media session state, shown when no track is loaded.
  String? _ambientTitle;
  bool _ambientPlaying = false;
  Future<void> Function()? onAmbientPlay;
  Future<void> Function()? onAmbientPause;
  Future<void> Function()? onAmbientStop;

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

  late final AudioRadioController _radioCtrl;

  bool get isRadioActive => _radioCtrl.isActive;
  Track? get radioSeed => _radioCtrl.seed;
  RadioMode get radioMode => _radioCtrl.mode;
  RadioStatus get radioStatus => _radioCtrl.status;
  bool get radioUsesLastFm => _radioCtrl.usesLastFm;
  RadioReason? radioReasonFor(String trackId) => _radioCtrl.reasonFor(trackId);

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

  /// Fires when [position] or [bufferedPosition] move, which happens many
  /// times a second while playing. Those ticks don't go through
  /// [notifyListeners]: that would re-run every selector and dependent
  /// provider in the app for a number only progress bars and synced lyrics
  /// show. Read them with AudioProgressSelector.
  Listenable get progressListenable => _progress;
  final _ProgressNotifier _progress = _ProgressNotifier();

  void _setPosition(Duration value) {
    if (value == _position) return;
    _position = value;
    _progress.tick();
  }

  void _setBufferedPosition(Duration value) {
    if (value == _bufferedPosition) return;
    _bufferedPosition = value;
    _progress.tick();
  }
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

  void attachDeferredMediaHandler(TsukiAudioHandler? handler) {
    if (handler != null && _mediaHandler == null) _attachMediaHandler(handler);
  }

  void _attachMediaHandler(TsukiAudioHandler handler) {
    _mediaHandler = handler;
    handler.onPlay = () async {
      if (_showsAmbient) return onAmbientPlay?.call();
      if (!_isPlaying) await togglePlay();
    };
    handler.onPause = () async {
      if (_showsAmbient) return onAmbientPause?.call();
      if (_isPlaying) await togglePlay();
    };
    handler.onStop = () async {
      await stop();
      await onAmbientStop?.call();
    };
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
    _syncHomeWidget();
    super.notifyListeners();
  }

  // Last song / play state written to the home screen widget.
  String? _widgetTrackKey;
  bool? _widgetPlayingKey;

  /// Keeps the player widget on the home screen showing the current song
  /// and play/pause state; only writes when one of them changed.
  void _syncHomeWidget() {
    final trackKey = _currentTrack?.id;
    if (trackKey == _widgetTrackKey && _isPlaying == _widgetPlayingKey) return;
    _widgetTrackKey = trackKey;
    _widgetPlayingKey = _isPlaying;
    unawaited(HomeWidgetService().updateTrack(_currentTrack, isPlaying: _isPlaying));
  }

  bool get _showsAmbient => _currentTrack == null && _ambientTitle != null;

  void setAmbientMediaState({required String? title, required bool playing}) {
    _ambientTitle = title;
    _ambientPlaying = playing;
    _syncMediaSession();
  }

  void _syncAmbientMediaSession(TsukiAudioHandler handler, bool force) {
    final itemKey = 'ambient|$_ambientTitle';
    if (itemKey != _mediaItemKey) {
      _mediaItemKey = itemKey;
      handler.mediaItem.add(MediaItem(
        id: 'tsuki_ambient',
        title: _ambientTitle!,
        artist: 'Tsuki Tunes',
      ));
    }
    final stateKey = 'ambient|$_ambientPlaying|$itemKey';
    if (!force && stateKey == _mediaStateKey) return;
    _mediaStateKey = stateKey;
    handler.playbackState.add(PlaybackState(
      controls: [
        _ambientPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: _ambientPlaying,
    ));
  }

  void _syncMediaSession({bool force = false}) {
    final handler = _mediaHandler;
    if (handler == null) return;
    if (_showsAmbient) {
      _syncAmbientMediaSession(handler, force);
      return;
    }
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

  /// Fired once per play when it has really been listened to: 30 seconds or
  /// half the track, whichever comes first (the usual "counts as a play" rule).
  Function(Track)? onPlayCounted;
  int _countedGeneration = -1;

  /// The track reached its end (or crossfaded into the next): not skipped.
  Function(Track)? onTrackCompleted;

  void _checkPlayCounted() {
    if (_countedGeneration == _playGeneration) return;
    final track = _currentTrack;
    if (track == null || _duration <= Duration.zero) return;
    final half = Duration(milliseconds: _duration.inMilliseconds ~/ 2);
    final needed = half < const Duration(seconds: 30) ? half : const Duration(seconds: 30);
    if (_position < needed) return;
    _countedGeneration = _playGeneration;
    onPlayCounted?.call(track);
  }

  @visibleForTesting
  void checkPlayCountedForTesting() => _checkPlayCounted();

  void _checkListenedThreshold() {
    _checkPlayCounted();
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
  Duration? get sleepTimerRemaining => _sleepCtrl.remaining;
  bool get isSleepTimerActive => _sleepCtrl.isActive;
  int? get sleepTimerOriginalMinutes => _sleepCtrl.originalMinutes;
  int? get nextShuffleIndex => _q.nextShuffleIndex;

  @visibleForTesting
  List<int> get playHistory => _q.history;

  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  DateTime? get sleepTimerDeadline => _sleepCtrl.deadline;

  @visibleForTesting
  void setSleepTimerDeadlineForTesting(DateTime? deadline) {
    // ignore: invalid_use_of_visible_for_testing_member
    _sleepCtrl.setDeadlineForTesting(deadline);
  }

  @visibleForTesting
  void setPositionForTesting(Duration pos) {
    _setPosition(pos);
  }

  /// Pretends the current play started [by] earlier, past the grace periods.
  @visibleForTesting
  void backdatePlayStartForTesting(Duration by) {
    _lastPlayStart = _lastPlayStart.subtract(by);
    _lastPlayCommandTime = _lastPlayCommandTime.subtract(by);
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

  /// Downloads the previews of the next [count] songs in play order
  /// (shuffle included), nearest first and one at a time, so the very next
  /// song is ready soonest on a weak connection. A newer call (the song
  /// changed) takes over from this one.
  void _prefetchUpcoming([int count = _precacheAhead]) {
    if (_q.isEmpty) return;
    final upcoming = [for (final i in _q.peekUpcoming(count)) _q.tracks[i]];
    if (upcoming.isEmpty) return;
    for (final track in upcoming) {
      onPrecacheTrackForTesting?.call(track);
    }
    final gen = ++_precacheGeneration;
    unawaited(() async {
      for (final track in upcoming) {
        if (gen != _precacheGeneration) return;
        await _precache(track);
      }
    }());
  }
  @visibleForTesting
  void prefetchUpcomingForTesting([int count = _precacheAhead]) =>
      _prefetchUpcoming(count);

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
    _service.loudnessFor = _loudnessFor;
    _sleepCtrl = SleepTimerController(
      service: _service,
      onStateChanged: notifyListeners,
      onStop: stop,
    );
    _radioCtrl = AudioRadioController(
      queue: _q,
      onStateChanged: notifyListeners,
      persistPlaybackState: () async => _persistPlaybackState(),
      isOnline: () => _online,
    );
    WidgetsBinding.instance.addObserver(this);
    _initAudioSession();
    _initSubscriptions();
    // Once both are known, a Spotify still playing our queue after Tsuki
    // was killed is picked up instead of the restored song shown paused.
    unawaited(Future.wait([_restorePlaybackState(), _initSpotify()])
        .then((_) => _adoptRunningSpotify())
        .catchError((Object e) {
      debugPrint('[AudioProvider] startup Spotify check failed: $e');
    }));
    _initCrossfade();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistPlaybackState();
    }
    if (state == AppLifecycleState.resumed) {
      _sleepCtrl.check();
      _checkBackgroundCompletion();
      if (_useSpotify && _spotifyActive) {
        _startPositionTimer();
        _syncSpotifyPlaybackState();
      } else if (_useSpotify && !_isPlaying) {
        unawaited(_adoptRunningSpotify());
      }
      // The system may have killed Spotify while we were in the background.
      if (_useSpotify) _warmUpSpotifyDevice();
    }
  }

  void _checkBackgroundCompletion() {
    if (_currentTrack == null) return;
    if (_useSpotify && _spotifyActive) {
      // Spotify knows our next songs: the state sync on resume follows it.
      if (_nativePlayer.isConnected || _spotifyAhead.isNotEmpty) return;
      final elapsed = DateTime.now().difference(_spotifySyncTime);
      final estimatedPos = _spotifySyncPosition + elapsed;
      if (estimatedPos >= _duration + const Duration(seconds: 3) &&
          _duration > Duration.zero) {
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
        _isPlaying,
        _radioSnapshot(),
      );
    });
  }

  Map<String, dynamic>? _radioSnapshot() =>
      _radioCtrl.snapshot(_q.tracks.map((t) => t.id));

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
      _isPlaying,
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
      final wasPlaying = state['wasPlaying'] as bool? ?? false;
      final savedAtMs = state['savedAt'] as int?;

      // Detect stale track completion after process death: if the track was
      // playing when persisted and enough wall-clock time has passed for it to
      // have ended, advance to the next track instead of restoring the old one.
      if (wasPlaying && savedAtMs != null && restoredQueue.length > 1) {
        final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
        final elapsed = DateTime.now().difference(savedAt);
        final trackDur = Duration(
            seconds: restoredTrack.durationSeconds > 0
                ? restoredTrack.durationSeconds
                : 30);
        final estimatedPos = Duration(milliseconds: posMs) + elapsed;
        if (estimatedPos >= trackDur) {
          final nextIndex = (restoredIndex + 1) % restoredQueue.length;
          final nextTrack = restoredQueue[nextIndex];
          _q.restore(restoredQueue, nextIndex);
          _currentTrack = nextTrack;
          _setPosition(Duration.zero);
          _duration = Duration(
              seconds: nextTrack.durationSeconds > 0
                  ? nextTrack.durationSeconds
                  : 30);
          _isPlaying = false;
          _isBuffering = false;
          _prefetchNextTrack();
          notifyListeners();
          debugPrint('[AudioProvider] Track "${restoredTrack.title}" would have ended during background; advanced to "${nextTrack.title}"');
          return;
        }
      }

      _q.restore(restoredQueue, restoredIndex);
      _currentTrack = restoredTrack;
      _setPosition(Duration(milliseconds: posMs));
      _duration = Duration(
          seconds: restoredTrack.durationSeconds > 0
              ? restoredTrack.durationSeconds
              : 30);
      _isPlaying = false;
      _isBuffering = false;

      final rawRadio = state['radio'];
      if (rawRadio is Map) {
        _radioCtrl.restoreFrom(Map<String, dynamic>.from(rawRadio), restoredQueue);
      }

      _prefetchNextTrack();
      notifyListeners();
      // Make sure the restored radio has songs lined up before they're due.
      if (_radioCtrl.isActive) unawaited(_radioCtrl.topUp());
      debugPrint('[AudioProvider] Restored playback state: "${restoredTrack.title}" at ${posMs}ms (${_q.length} tracks in queue${_radioCtrl.isActive ? ', radio on' : ''})');
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
      final prefs = await SharedPreferences.getInstance();
      _normalizeVolume = prefs.getBool(_normalizeKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioProvider] Error loading saved crossfade: $e');
    }
  }

  // ── Loudness normalization (Deezer previews only) ──

  static const _normalizeKey = 'normalize_preview_volume';
  bool _normalizeVolume = true;
  bool get normalizeVolume => _normalizeVolume;

  double _loudnessFor(Track track) => _normalizeVolume
      ? Loudness.factorFor(BpmService.shared.cachedGain(track.id))
      : 1.0;

  Future<void> setNormalizeVolume(bool enabled) async {
    _normalizeVolume = enabled;
    notifyListeners();
    final track = _currentTrack;
    if (track != null) {
      _service.refreshLoudness(track);
      if (enabled) unawaited(_ensureLoudness(track));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_normalizeKey, enabled);
    } catch (_) {}
  }

  /// Fetches the loudness of [track] if unknown (then glides to it) and of
  /// the next few, so they start at the right volume. Spotify normalizes on
  /// its own, so its playback is left alone.
  Future<void> _ensureLoudness(Track track) async {
    if (!_normalizeVolume || (_useSpotify && !_spotifyFallbackActive)) return;
    if (BpmService.shared.cachedGain(track.id) == null) {
      await BpmService.shared.gainFor(track.id);
      if (_currentTrack?.id == track.id) _service.refreshLoudness(track);
    }
    for (final next in upcomingTracks.take(3)) {
      await BpmService.shared.gainFor(next.id);
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
      if (!_isOurSpotifyUri(_nativePlayer.lastTrackUri)) {
        _onSpotifyLeftTrack(
            _nativePlayer.lastTrackUri, Duration(milliseconds: pos));
        return;
      }
      // A single track that ends without autoplay leaves Spotify paused:
      // that is the end of our track, not the user pausing.
      if (paused && _isPlaying && !_isBuffering && _duration > Duration.zero) {
        final estimated =
            _spotifySyncPosition + DateTime.now().difference(_spotifySyncTime);
        if (pos >= dur - 1500 ||
            estimated >= _duration - const Duration(seconds: 3)) {
          debugPrint('[AudioProvider] Spotify stopped at the end of the track, advancing');
          _stopPositionTimer();
          _handleTrackCompleted();
          return;
        }
      }
      _spotifySyncPosition = Duration(milliseconds: pos);
      _spotifySyncTime = DateTime.now();
      _setPosition(_spotifySyncPosition);
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

    // Android often drops the App Remote link while we are in the background
    // and Spotify keeps playing, so losing it says nothing about playback:
    // ask the Web API instead (the timer keeps polling it from now on).
    _nativePlayer.onDisconnected = () {
      if (!_spotifyActive || !_isPlaying) return;
      debugPrint('[AudioProvider] App Remote link lost, checking Spotify through the Web API');
      unawaited(_syncSpotifyPlaybackState());
    };

    await _spotify.loadSavedState();
    _useSpotify = _spotify.isConnected && _spotify.isPremium;
    if (_useSpotify) {
      _warmUpSpotifyDevice();
    }
  }

  bool _warmingUpSpotify = false;

  /// Makes sure the Spotify app on this phone is running so playback works
  /// without the user opening Spotify by hand. Another device (PC, speaker)
  /// being listed doesn't count: only an active Smartphone does.
  void _warmUpSpotifyDevice() {
    if (_warmingUpSpotify || _nativePlayer.isConnected) return;
    _warmingUpSpotify = true;
    Future.microtask(() async {
      try {
        final devices = await _spotify.getDevices();
        final phoneActive = devices.any(
            (d) => d['type'] == 'Smartphone' && d['is_active'] == true);
        if (phoneActive) {
          debugPrint('[AudioProvider] Spotify pre-warm: phone already active');
          return;
        }

        // Connecting App Remote launches Spotify in the background (no UI).
        final token = _spotify.accessToken;
        if (token == null) return;
        debugPrint('[AudioProvider] Spotify not active on this phone, waking via App Remote...');
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
      } finally {
        _warmingUpSpotify = false;
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
        final raw = _spotifySyncPosition + elapsed;
        _setPosition(_duration > Duration.zero && raw > _duration ? _duration : raw);
        // When the App Remote is connected it reports the real end-of-track
        // via onStateChanged (paused=true), so don't race it with an
        // estimated position that can overshoot by a few seconds.  Only
        // trigger completion from the estimate when we're polling the Web
        // API (no real-time state) and even then allow a 3-second cushion
        // so Spotify's own crossfade can finish naturally.
        final pastEnd = _duration > Duration.zero &&
            raw >= _duration + const Duration(seconds: 3);
        // With our next songs handed to Spotify it moves on by itself:
        // follow what it reports instead of starting the next one.
        if (pastEnd && !hasRealTimeState && _spotifyAhead.isEmpty) {
          _stopPositionTimer();
          _handleTrackCompleted();
        } else {
          _maybePersistPosition();
          _checkListenedThreshold();
          _checkSpotifyCrossfade();
          final interval =
              pastEnd && _spotifyAhead.isNotEmpty ? 3 : pollInterval;
          if (_spotifyPollTick % interval == 0) {
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
        // A failed request (no network in Doze, rate limit) tells us nothing.
        if (_spotify.lastPlaybackStateFailed) return;
        // No Spotify session at all (app closed or frozen).
        final sincePlay = DateTime.now().difference(_lastPlayCommandTime);
        final nativePlaying = _nativePlayingOurTrack;

        // Check if the track should have ended while Spotify was gone.
        if (!nativePlaying && sincePlay.inSeconds >= 10) {
          final elapsed = DateTime.now().difference(_spotifySyncTime);
          final estimatedPos = _spotifySyncPosition + elapsed;
          if (_isPlaying &&
              estimatedPos >= _duration &&
              _duration > Duration.zero) {
            debugPrint('[AudioProvider] Spotify session gone, track would have ended; advancing');
            _stopPositionTimer();
            _completionHandled = false;
            _crossfadeTriggered = false;
            _handleTrackCompleted();
            return;
          }
          if (_isPlaying) {
            debugPrint('[AudioProvider] Spotify session gone, marking paused');
            _isPlaying = false;
            _stopPositionTimer();
            notifyListeners();
          }
        }
        return;
      }

      final progressMs = state['progress_ms'] as int? ?? 0;
      final isPlaying = state['is_playing'] as bool? ?? false;
      final item = state['item'] as Map<String, dynamic>?;
      final durationMs = item?['duration_ms'] as int? ?? 0;

      // Detect playback transferred to another device or Spotify auto-advanced
      if (item != null && _currentTrack != null && _currentSpotifyUri != null) {
        final playingUri = item['uri'] as String?;
        // Spotify may relink the track to another market's version.
        final linkedUri = (item['linked_from'] as Map?)?['uri'] as String?;
        if (linkedUri == _currentSpotifyUri) _linkedSpotifyUri = playingUri;
        if (playingUri != null && !_isOurSpotifyUri(playingUri)) {
          _onSpotifyLeftTrack(playingUri, Duration(milliseconds: progressMs));
          return;
        }
      }

      if (durationMs > 0) {
        _duration = Duration(milliseconds: durationMs);
      }

      if (!_nativePlayer.isConnected) {
        _spotifySyncPosition = Duration(milliseconds: progressMs);
        _spotifySyncTime = DateTime.now();
        _setPosition(_spotifySyncPosition);
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

  bool _isOurSpotifyUri(String? uri) =>
      uri != null && (uri == _currentSpotifyUri || uri == _linkedSpotifyUri);

  bool get _nativePlayingOurTrack =>
      (_currentSpotifyUri != null &&
          _nativePlayer.isPlayingUri(_currentSpotifyUri!)) ||
      (_linkedSpotifyUri != null &&
          _nativePlayer.isPlayingUri(_linkedSpotifyUri!));

  /// Spotify URIs for our next songs in play order, stopping at the first
  /// one Spotify doesn't have (URIs are cached, so repeats are instant).
  /// With a [budget], stops resolving once it runs out.
  Future<List<({String trackId, String uri})>> _resolveAhead(
      {Duration? budget}) async {
    if (_sleepCtrl.stopAfterCurrentTrack) return const [];
    final started = DateTime.now();
    final upcoming = [
      for (final i in _q.peekUpcoming(_spotifyAheadMax)) _q.tracks[i],
    ];
    final out = <({String trackId, String uri})>[];
    for (final t in upcoming) {
      if (budget != null && DateTime.now().difference(started) > budget) break;
      final uri = await _resolveSpotifyUri(t);
      if (uri == null) break;
      out.add((trackId: t.id, uri: uri));
    }
    return out;
  }

  /// Spotify moved through the list we handed it, [k] + 1 songs along:
  /// catch our queue up without a new play (which would restart the song).
  /// If our queue changed since the list was sent, take over with a fresh
  /// play instead, at the very start of the song.
  void _followSpotify(int k, Duration progress) {
    final passed = _spotifyAhead.sublist(0, k + 1);
    final expected = [for (final i in _q.peekUpcoming(k + 1)) _q.tracks[i].id];
    final stale = expected.length != passed.length ||
        [for (var i = 0; i < passed.length; i++) expected[i] == passed[i].trackId]
            .contains(false);
    if (stale ||
        _sleepCtrl.stopAfterCurrentTrack ||
        _q.repeatMode == PlaybackRepeatMode.one) {
      debugPrint('[AudioProvider] Spotify list out of date, taking over');
      _spotifyAhead = const [];
      _stopPositionTimer();
      _completionHandled = false;
      _handleTrackCompleted();
      return;
    }

    final finished = _currentTrack;
    if (finished != null) onTrackCompleted?.call(finished);
    for (var i = 0; i <= k; i++) {
      _q.next(online: true, canPlay: (_) => true);
    }
    final track = _q.current;
    if (track == null) return;
    debugPrint('[AudioProvider] Spotify moved on to "${track.title}", following');
    _radioCtrl.registerLeaving(track, finished, _position, _duration,
        completed: true);

    final now = DateTime.now();
    _spotifyAhead = _spotifyAhead.sublist(k + 1);
    _currentTrack = track;
    _currentSpotifyUri = passed.last.uri;
    _linkedSpotifyUri = null;
    _spotifyTookOver = false;
    _playGeneration++;
    _completionHandled = false;
    _crossfadeTriggered = false;
    _lastPlayStart = now;
    _lastPlayCommandTime = now;
    _setPosition(progress);
    _spotifySyncPosition = progress;
    _spotifySyncTime = now;
    _duration =
        Duration(seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    _isBuffering = false;
    _isPlaying = true;
    _startPositionTimer();
    onTrackStarted?.call(track);
    _persistPlaybackState();
    notifyListeners();
    _prefetchNextTrack();
    unawaited(_radioCtrl.topUp());
    if (_spotifyAhead.length < 2) unawaited(_reissueSpotifyAhead());
  }

  /// Hands Spotify a fresh list from the current song on, from where it is,
  /// so it never runs out of our queue. Only near a song's start, where the
  /// brief restart goes unnoticed; otherwise the next song boundary does it.
  Future<void> _reissueSpotifyAhead() async {
    final gen = _playGeneration;
    final uri = _currentSpotifyUri;
    if (uri == null || !_spotifyActive) return;
    final ahead = await _resolveAhead();
    if (gen != _playGeneration || !_spotifyActive) return;
    if (ahead.length <= _spotifyAhead.length) return;
    final pos =
        _spotifySyncPosition + DateTime.now().difference(_spotifySyncTime);
    if (pos > const Duration(seconds: 8)) return;
    final ok = await _spotify.play(
      trackUris: [uri, ...ahead.map((e) => e.uri)],
      positionMs: pos.inMilliseconds,
    );
    if (gen != _playGeneration || !ok) return;
    _spotifyAhead = ahead;
    _lastPlayCommandTime = DateTime.now();
  }

  /// Tsuki was closed or killed while Spotify kept playing our queue: pick
  /// up the song it's on (when it's one of ours) instead of showing the old
  /// one paused.
  Future<void> _adoptRunningSpotify() async {
    if (!_useSpotify || _q.isEmpty || _isPlaying || _spotifyActive) return;
    final state = await _spotify.getPlaybackState();
    if (state == null || state['is_playing'] != true) return;
    if (_isPlaying || _spotifyActive) return;
    final item = state['item'] as Map<String, dynamic>?;
    final uri = item?['uri'] as String?;
    final name = item?['name'] as String?;
    if (item == null || uri == null || name == null) return;
    final artists = [
      for (final a in (item['artists'] as List? ?? const []))
        if (a is Map) (a['name'] as String? ?? '').toLowerCase(),
    ];
    final idx = queueIndexMatching(_q.tracks, name, artists,
        from: _q.currentIndex < 0 ? 0 : _q.currentIndex);
    if (idx == null) return;

    final track = _q.tracks[idx];
    _q.select(track);
    final progress = Duration(milliseconds: state['progress_ms'] as int? ?? 0);
    final durationMs = item['duration_ms'] as int? ?? 0;
    final now = DateTime.now();
    debugPrint('[AudioProvider] Spotify is playing "${track.title}" from our queue, picking it up');
    _currentTrack = track;
    _currentSpotifyUri = uri;
    _linkedSpotifyUri = null;
    _spotifyActive = true;
    _spotifyFallbackActive = false;
    _spotifyTookOver = false;
    _spotifyAhead = const [];
    _isPlaying = true;
    _isBuffering = false;
    _setPosition(progress);
    _spotifySyncPosition = progress;
    _spotifySyncTime = now;
    _lastPlayCommandTime = now;
    _lastPlayStart = now.subtract(progress);
    _duration = durationMs > 0
        ? Duration(milliseconds: durationMs)
        : Duration(seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
    _playGeneration++;
    _completionHandled = false;
    _startPositionTimer();
    notifyListeners();
    _prefetchNextTrack();
  }

  /// Index of the queue track that is [title] by one of [artists], looking
  /// from [from] onwards first. Version tags like "(Remix)" are ignored.
  @visibleForTesting
  static int? queueIndexMatching(
    List<Track> queue,
    String title,
    List<String> artists, {
    int from = 0,
  }) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'\s+-\s+.*$'), '')
        .trim();
    final wanted = norm(title);
    for (var k = 0; k < queue.length; k++) {
      final i = (from + k) % queue.length;
      final t = queue[i];
      if (norm(t.title) != wanted) continue;
      final a = t.artistName.toLowerCase();
      if (artists.isEmpty ||
          artists.any((x) => x.isNotEmpty && (x.contains(a) || a.contains(x)))) {
        return i;
      }
    }
    return null;
  }

  /// Spotify is on a track other than ours: the next song of the list we
  /// handed it (follow along), past the end of ours into its autoplay
  /// (advance our queue, which replaces it), or something someone picked in
  /// the Spotify app (stop claiming it).
  void _onSpotifyLeftTrack(String? uri, Duration otherProgress) {
    if (_isBuffering || _completionHandled || _crossfadeTriggered) return;
    final k = uri == null ? -1 : _spotifyAhead.indexWhere((e) => e.uri == uri);
    if (k != -1) {
      _followSpotify(k, otherProgress);
      return;
    }
    if (DateTime.now().difference(_lastPlayCommandTime).inSeconds < 5) return;

    if (_isPlaying && _duration > Duration.zero) {
      final estimated =
          _spotifySyncPosition + DateTime.now().difference(_spotifySyncTime);
      // Where our track was when the other one started.
      final atSwitch = estimated - otherProgress;
      if (estimated >= _duration ||
          atSwitch >= _duration - const Duration(seconds: 10)) {
        debugPrint('[AudioProvider] Spotify moved on after our track ended, advancing queue');
        _stopPositionTimer();
        _handleTrackCompleted();
        return;
      }
    }

    if (_spotifyTookOver) return;
    debugPrint('[AudioProvider] Spotify switched to another track, no longer ours');
    _spotifyTookOver = true;
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
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
        _setPosition(pos);
        _checkCrossfade(pos);
        if (_isPlaying) {
          _maybePersistPosition();
          _checkListenedThreshold();
        }
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
        _setBufferedPosition(buf);
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
    if (newQueue != null) _radioCtrl.radio = null;
    _radioCtrl.registerLeaving(track, _currentTrack, _position, _duration);
    _q.select(track, newQueue: newQueue);
    if (newQueue != null && newQueue.isNotEmpty) _prefetchUpcoming();

    _retryTimer?.cancel();
    _retryCount = 0;
    _currentTrack = track;
    _setPosition(Duration.zero);
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
      unawaited(_ensureLoudness(track));
      _persistPlaybackState();
      _prefetchNextTrack();
      unawaited(_radioCtrl.topUp());
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

    if (!_online) {
      // No connection (metro, plane): Spotify can't be searched or told to
      // play, so play the preview downloaded ahead of time right away
      // instead of waiting on requests that will time out.
      debugPrint('Spotify: offline, playing the cached preview of "${track.title}"');
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      if (_nativePlayer.isConnected) {
        try {
          await _nativePlayer.pause();
        } catch (_) {}
      }
      await _service.playTrack(track);
      if (gen != _playGeneration) return;
      _isBuffering = false;
      notifyListeners();
      return;
    }

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
    _linkedSpotifyUri = null;
    _spotifyTookOver = false;
    _spotifyAhead = const [];

    // Preferred: hand Spotify the next songs of our queue along with this
    // one. It then plays them by itself, so the queue goes on even when
    // Android freezes or kills Tsuki in the background (otherwise Spotify
    // falls into its own autoplay when the song ends).
    final ahead =
        await _resolveAhead(budget: const Duration(milliseconds: 1200));
    if (gen != _playGeneration) return;
    if (ahead.isNotEmpty) {
      final ok =
          await _spotify.play(trackUris: [uri, ...ahead.map((e) => e.uri)]);
      if (gen != _playGeneration) return;
      if (ok) {
        debugPrint('Spotify: playing with ${ahead.length} queued songs ahead');
        _spotifyAhead = ahead;
        _spotifyActive = true;
        _spotifyFallbackActive = false;
        _isPlaying = false;
        _isBuffering = true;
        _setPosition(Duration.zero);
        _lastPlayCommandTime = DateTime.now();
        notifyListeners();
        _prefetchNextTrack();
        unawaited(_resolveAhead());
        unawaited(_verifySpotifyPlayback(gen, uri, track));
        return;
      }
      debugPrint('Spotify: list play failed, playing the single song');
    }

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
        _setPosition(Duration.zero);
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
    _setPosition(Duration.zero);
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
        // App Remote plays the single song: Spotify no longer has the list.
        _spotifyAhead = const [];
        final now = DateTime.now();
        _setPosition(Duration.zero);
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
    _setPosition(Duration.zero);
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
  /// take audio focus and immediately pause the preview, so stop it first,
  /// through the Web API too when App Remote is down: otherwise Spotify can
  /// keep playing (e.g. its autoplay) on top of the preview.
  Future<void> _playPreviewInsteadOfSpotify(Track track) async {
    try {
      await _spotifyPause();
    } catch (_) {}
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
      if (linked?['uri'] == uri) _linkedSpotifyUri = item?['uri'] as String?;
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
    if (_nativePlayingOurTrack) return;
    final state = await _spotify.getPlaybackState();
    if (!_spotifyActive || !_isPlaying) return;
    if (state == null && _spotify.lastPlaybackStateFailed) return;
    if (state != null && state['is_playing'] == true) return;
    debugPrint('[AudioProvider] Spotify did not resume after interruption, marking paused');
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
  }

  Future<void> _precache(Track track) async {
    if (!_online) return;
    if (_precacheWifiOnly && (_connectivityProvider?.isMetered ?? false)) {
      return;
    }
    try {
      await AudioPrecacheService().precacheTrack(await _withFreshPreview(track));
    } catch (e) {
      debugPrint('[AudioProvider] Precache non-fatal error: $e');
    }
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

    // 1. Previews of the next songs, also with Spotify: if the connection
    // drops, they play instead of nothing.
    _prefetchUpcoming();

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
      if (!_isPlaying && _spotifyTookOver && _currentTrack != null) {
        // Spotify moved on to something else: resuming there would keep
        // playing that, so start our track again where it was.
        final savedPos = _position;
        await playTrack(_currentTrack!);
        if (savedPos > Duration.zero) await seek(savedPos);
        return;
      }
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
    _spotifyTookOver = false;
    await _service.stop();
    _currentTrack = null;
    _isPlaying = false;
    _isBuffering = false;
    _setPosition(Duration.zero);
    _radioCtrl.radio = null;
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    _setPosition(pos);
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
  /// Spotify plays full songs on its own player, whose speed can't be set.
  bool get canChangeTempo => !_useSpotify || _spotifyFallbackActive;

  /// Playback speed per track (running mode locks songs onto the steps).
  /// Null plays everything at normal speed.
  set tempoFor(double Function(Track track)? fn) {
    _service.speedFor = fn == null ? null : (t) => canChangeTempo ? fn(t) : 1.0;
    refreshTempo();
  }

  /// Speed the current track actually plays at.
  double get playbackSpeed => canChangeTempo ? _service.speed : 1.0;

  /// Applies the current [tempoFor] to the playing track, gliding there.
  void refreshTempo() {
    final track = _currentTrack;
    if (track != null) _service.refreshSpeed(track);
  }

  /// The tracks after the current one, in play order.
  List<Track> get upcomingTracks =>
      _q.isEmpty ? const [] : _q.tracks.sublist(_q.currentIndex + 1);

  /// Applies a new order to the upcoming tracks (e.g. the BPM flow). Shuffle
  /// is turned off, otherwise it would ignore the order.
  void setUpcomingOrder(List<Track> upcoming) {
    if (_q.isShuffle) _q.toggleShuffle();
    _q.replaceUpcoming(upcoming);
    _prefetchedTargetTrackId = null;
    _prefetchNextTrack();
    _persistPlaybackState();
    notifyListeners();
  }

  /// Whether [trackId] was queued by hand and is still waiting to play.
  bool isUserQueued(String trackId) => _q.isUserQueued(trackId);

  /// Plays [track] right after the current one. [userQueued] false is for
  /// tracks the app picks itself (running mode).
  void playNext(Track track, {bool userQueued = true}) {
    if (!_q.insertNext(track, userQueued: userQueued)) return;
    _queueChanged();
  }

  /// Queues tracks after the current one and anything queued before them,
  /// ahead of the rest of the album or playlist, like Spotify's queue.
  void addToQueue(Track track) => addAllToQueue([track]);
  void addAllToQueue(List<Track> tracks) {
    if (_q.enqueue(tracks) == 0) return;
    _queueChanged();
  }

  void _queueChanged() {
    _prefetchedTargetTrackId = null;
    _prefetchNextTrack();
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
    unawaited(_radioCtrl.topUp());
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
    final finished = _currentTrack;
    if (finished != null) onTrackCompleted?.call(finished);

    if (_sleepCtrl.handleTrackEnd()) return;

    if (_q.repeatMode == PlaybackRepeatMode.one && _currentTrack != null) {
      playTrack(_currentTrack!);
    } else if (_q.repeatMode == PlaybackRepeatMode.all) {
      next();
    } else if (_q.shouldStopAtEnd()) {
      if (_radioCtrl.isActive) {
        unawaited(
            _radioCtrl.topUp(force: true).then((added) => added ? next() : stop()));
      } else {
        stop();
      }
    } else {
      next();
    }
  }

  // ---------------------------------------------------------------------------
  // Song radio (delegated to AudioRadioController)
  // ---------------------------------------------------------------------------

  Future<bool> startRadio(Track seed) => _radioCtrl.start(
        seed,
        currentTrack: _currentTrack,
        playTrack: playTrack,
        clearQueue: () {
          _prefetchedTargetTrackId = null;
          _q.clear(keep: _currentTrack);
          _persistPlaybackState();
        },
      );

  void stopRadio() => _radioCtrl.stop();

  Future<void> setRadioMode(RadioMode mode) => _radioCtrl.setMode(mode);

  Future<void> radioMoreLikeThis() async {
    final track = _currentTrack;
    if (track == null) return;
    await _radioCtrl.moreLikeThis(track);
  }

  Future<void> radioLessLikeThis() async {
    final track = _currentTrack;
    if (track == null) return;
    await _radioCtrl.lessLikeThis(track, next: next);
  }

  void _checkCrossfade(Duration pos) {
    if (_q.repeatMode == PlaybackRepeatMode.one) return;
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered) return;
    if (_useSpotify && !_spotifyFallbackActive) return;
    if (_sleepCtrl.stopAfterCurrentTrack) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (pos.inSeconds < 2) return;

    final remaining = _duration - pos;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerCrossfade();
    }
  }

  void _checkSpotifyCrossfade() {
    // Spotify handles crossfade natively in its own app. Triggering a
    // _playViaSpotify() call early causes an abrupt skip instead of a smooth
    // transition, so we let Spotify finish the track on its own and advance
    // the queue through the normal _handleTrackCompleted() path.
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
    _radioCtrl.registerLeaving(nextTrack, _currentTrack, _position, _duration, completed: true);
    final outgoing = _currentTrack;
    if (outgoing != null) onTrackCompleted?.call(outgoing);
    _currentTrack = nextTrack;
    _setPosition(Duration.zero);
    _duration = Duration(
        seconds: nextTrack.durationSeconds > 0 ? nextTrack.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;

    debugPrint('[AudioProvider] Starting crossfade to "${nextTrack.title}" (${_crossfadeSeconds}s)');
    notifyListeners();
    onTrackStarted?.call(nextTrack);
    unawaited(_ensureLoudness(nextTrack));
    _prefetchNextTrack();
    unawaited(_radioCtrl.topUp());

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

  void setSleepTimer(Duration? duration) => _sleepCtrl.set(duration);

  void checkSleepTimer() => _sleepCtrl.check();

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
    _sleepCtrl.dispose();
    _progress.dispose();
    _nativePlayer.dispose();
    _service.dispose();
    super.dispose();
  }
}

class _ProgressNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}
