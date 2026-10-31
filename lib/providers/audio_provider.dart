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

part 'audio_media_session.dart';
part 'audio_playback_errors.dart';
part 'audio_playback_state.dart';
part 'audio_spotify_playback.dart';

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
  // The market version Spotify actually plays when it relinks that URI.
  String? _linkedSpotifyUri;
  // Spotify moved on to a track we didn't ask for; resuming must replay ours.
  bool _spotifyTookOver = false;
  // Our next songs, handed to Spotify along with the current one, in play
  // order. Spotify plays them by itself, so the queue goes on even when
  // Android freezes or kills Tsuki in the background.
  List<({String trackId, String uri})> _spotifyAhead = const [];
  // Paused by an audio interruption (a call); resumes when it ends.
  bool _spotifyInterrupted = false;
  bool _warmingUpSpotify = false;
  int _spotifyPollTick = 0;

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

  void setAmbientMediaState({required String? title, required bool playing}) {
    _ambientTitle = title;
    _ambientPlaying = playing;
    _syncMediaSession();
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

  @visibleForTesting
  PlaybackError classifyPlaybackError(Object error, [Track? track]) =>
      _classifyPlaybackError(error, track);

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
