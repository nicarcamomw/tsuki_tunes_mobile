import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/deezer_preview.dart';
import '../../data/datasources/audio_player_service.dart';
import '../../data/datasources/audio_precache_service.dart';
import '../../data/datasources/bpm_flow.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/headphones_service.dart';
import '../../data/datasources/home_widget_service.dart';
import '../../data/datasources/media_session_handler.dart';
import '../../data/datasources/spotify_service.dart';
import '../../data/datasources/spotify_web_player.dart';
import '../../data/datasources/storage_service.dart';
import '../../domain/entities/playback_error.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../domain/entities/smart_shuffle.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/playback_queue.dart';
import '../../domain/logic/song_radio.dart' show SongRadio;
import '../../domain/repositories/playback_controller.dart';
import 'audio_radio_controller.dart';
import 'audio_sleep_timer.dart';
import 'connectivity_provider.dart';

export '../../domain/entities/playback_error.dart';
export '../../domain/entities/repeat_mode.dart';
export '../../domain/entities/smart_shuffle.dart';
export '../../domain/logic/playback_queue.dart' show QueueSnapshot;
export 'audio_radio_controller.dart';

part 'audio_media_session.dart';
part 'audio_playback_errors.dart';
part 'audio_playback_state.dart';
part 'audio_spotify_playback.dart';

class AudioProvider extends ChangeNotifier with WidgetsBindingObserver implements PlaybackController {
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
  // The songs after the next one wait this long into a song, so they
  // don't slow its start; the next one downloads right away.
  static const _precacheStartDelay = Duration(seconds: 3);
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
  // Long enough that the list rarely has to be handed again (a brief
  // restart of the song), so Spotify's own crossfade and gapless playback
  // join song after song; short enough to look the songs up quickly.
  static const int _spotifyAheadMax = 12;
  // Whether Spotify loops the current song itself (our repeat-one), so it
  // starts over with no gap instead of Tsuki playing it again. Null until
  // set this session.
  bool? _spotifyLoopsTrack;
  // The list play failed for this song (Web API unusable): sending it again
  // a few seconds in would only restart the song.
  bool _spotifyListPlayFailed = false;
  // Our queue grew past the list Spotify has: hand it the longer one at
  // the next song's start.
  bool _spotifyExtendAtNextSong = false;
  // Queue edits wait a moment (several drags in a row) before Spotify gets
  // the new list; while paused it gets it on resume instead.
  Timer? _spotifyListTimer;
  bool _spotifyListStale = false;

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

  @override
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _q.tracks;
  int get currentIndex => _q.currentIndex;
  @override
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
    final cache = AudioPrecacheService();
    final missing = [
      for (final t in upcoming)
        if (!kIsWeb &&
            t.previewUrl.isNotEmpty &&
            cache.getCachedFilePath(t.id) == null)
          t
    ];
    if (missing.isEmpty) return;
    // The very next song first and at once: skipping soon must find it
    // ready, as before.
    final next = identical(missing.first, upcoming.first) ? missing.first : null;
    final later = next == null ? missing : missing.sublist(1);
    final sinceStart = DateTime.now().difference(_lastPlayStart);
    unawaited(() async {
      if (next != null) await _precache(next);
      if (later.isEmpty) return;
      final waited = DateTime.now().difference(_lastPlayStart);
      if (gen != _precacheGeneration) return;
      if (sinceStart < _precacheStartDelay && waited < _precacheStartDelay) {
        await Future.delayed(_precacheStartDelay - waited);
      }
      for (final track in later) {
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
      onQueueGrew: _onQueueGrew,
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
        // The Spotify app answers right away; the Web API backs it up.
        if (_nativePlayer.isConnected) unawaited(_refreshNativeState());
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
      // Spotify knows our next songs (or loops this one): the state sync on
      // resume follows it.
      if (_nativePlayer.isConnected ||
          _spotifyAhead.isNotEmpty ||
          _spotifyLoopsOurTrack) {
        return;
      }
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
      _autoplaySimilar = prefs.getBool(_autoplayKey) ?? true;
      await _loadShuffleSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioProvider] Error loading saved crossfade: $e');
    }
  }

  // ── Similar songs after the end ──

  static const _autoplayKey = 'tsuki_autoplay_similar';
  bool _autoplaySimilar = true;
  bool get autoplaySimilar => _autoplaySimilar;
  // The song a continuation was already tried for (it found nothing).
  String? _continueTriedFor;

  Future<void> setAutoplaySimilar(bool enabled) async {
    _autoplaySimilar = enabled;
    _continueTriedFor = null;
    notifyListeners();
    if (enabled) _maybeContinueWithSimilar();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoplayKey, enabled);
    } catch (_) {}
  }

  /// Whether the music may go on with similar songs once the queue ends.
  bool get _mayContinueWithSimilar =>
      _autoplaySimilar &&
      !_radioCtrl.isActive &&
      _q.repeatMode == PlaybackRepeatMode.off &&
      !_sleepCtrl.stopAfterCurrentTrack &&
      _online &&
      // Running mode picks the songs itself.
      _service.speedFor == null;

  /// What's playing is about to run out: add similar songs after it (a
  /// radio seeded with the song playing now). With Spotify this happens
  /// before the list handed to it reaches our last song, so it never gets
  /// to the end and starts its own autoplay: Tsuki stays in charge.
  void _maybeContinueWithSimilar() {
    final track = _currentTrack;
    if (track == null || !_mayContinueWithSimilar) return;
    if (_continueTriedFor == track.id) return;
    final left = _q.isShuffle
        ? _q.length - 1 - _q.played().length
        : _q.upcomingCount;
    final spotify = _useSpotify && _spotifyActive && !_spotifyFallbackActive;
    if (left > (spotify ? _spotifyAheadMax : 3)) return;
    _continueTriedFor = track.id;
    debugPrint('[AudioProvider] Queue ending, adding similar songs');
    unawaited(_radioCtrl.continueFrom(track));
  }

  /// Songs were added at the end (similar songs, radio): Spotify gets them
  /// before its list runs out, quietly at a song's start when it can.
  void _onQueueGrew() {
    _prefetchNextTrack();
    if (!_useSpotify || !_spotifyActive || _spotifyFallbackActive) return;
    if (_spotifyAhead.length >= _spotifyAheadMax) return;
    if (_spotifyAhead.length < 2) {
      // About to run out: now, even if the song restarts for a moment.
      unawaited(_reissueSpotifyAhead(force: true));
    } else {
      _spotifyExtendAtNextSong = true;
      unawaited(_reissueSpotifyAhead());
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
  Timer? _completionRecheck;
  /// Seconds between asks to the Spotify app for its state.
  static const int _nativeRefreshEvery = 3;
  int _nativeRefreshFailures = 0;

  StreamSubscription<void>? _unplugSub;

  /// Headphones out: pause, and stay paused (an interruption ending later
  /// must not resume it out of the speaker).
  void _onHeadphonesUnplugged() {
    _spotifyInterrupted = false;
    if (!_isPlaying) return;
    debugPrint('[AudioProvider] Headphones unplugged, pausing');
    if (_useSpotify && _spotifyActive && !_spotifyFallbackActive) {
      unawaited(_spotifyPause());
      _isPlaying = false;
      _stopPositionTimer();
      notifyListeners();
      _persistPlaybackState();
    } else {
      unawaited(_service.pause());
    }
  }

  @visibleForTesting
  void headphonesUnpluggedForTesting() => _onHeadphonesUnplugged();

  bool _warmingUpSpotify = false;


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

  @visibleForTesting
  Future<void> refreshSpotifyListForTesting() async {
    _spotifyListTimer?.cancel();
    await _refreshSpotifyList();
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

  @override
  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    // Playing an album/playlist replaces the radio; picking within the
    // queue keeps it and teaches it whether the last song was skipped.
    if (newQueue != null) _radioCtrl.radio = null;
    _radioCtrl.registerLeaving(track, _currentTrack, _position, _duration);
    _q.select(track, newQueue: newQueue);
    if (newQueue != null) {
      _recoRadio = null;
      _recoSteeredBy = null;
      if (_q.isShuffle) unawaited(_learnShuffleTempos());
    }
    // A new play hands Spotify a fresh list.
    _spotifyListTimer?.cancel();
    _spotifyListStale = false;
    _spotifyExtendAtNextSong = false;

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

  /// Once our song is playing in Spotify: match its repeat to ours and, if
  /// it only got this one song, hand it the next ones too, so it moves on
  /// by itself (with its crossfade) instead of stopping at the end.
  void _afterSpotifyStarted() {
    _keepMediaSessionOnTop();
    unawaited(_syncSpotifyRepeat());
    if (_spotifyAhead.isEmpty && !_spotifyListPlayFailed) {
      unawaited(_reissueSpotifyAhead());
    }
  }

  @visibleForTesting
  void afterSpotifyStartedForTesting() => _afterSpotifyStarted();

  Timer? _mediaTopTimer;


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

  @visibleForTesting
  int? peekNextIndex() => _q.peekNext();

  void _prefetchNextTrack() {
    _maybeContinueWithSimilar();
    if (_smartShuffle) unawaited(_topUpRecommendations());
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

  @override
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
        if (!await _spotifyPause()) {
          // Neither way took it: one more go before giving up. If Spotify
          // still plays, the state sync shows it playing again.
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await _spotifyPause();
        }
        _isPlaying = false;
        _stopPositionTimer();
      } else {
        final resumed = await _spotifyResume();
        _isPlaying = true;
        _lastPlayCommandTime = DateTime.now();
        _spotifySyncPosition = _position;
        _spotifySyncTime = DateTime.now();
        _startPositionTimer();
        if (!resumed && !await _replaySpotifyHere()) {
          debugPrint('[AudioProvider] Spotify could not resume');
          _isPlaying = false;
          _stopPositionTimer();
        } else {
          unawaited(_verifySpotifyResume(recover: true));
        }
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
    _spotifyListTimer?.cancel();
    _spotifyListStale = false;
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
    if (_q.isShuffle) {
      unawaited(_learnShuffleTempos());
    } else {
      _smartShuffle = false;
      _applyShuffleSettings();
      if (_q.dropRecommendations()) _persistPlaybackState();
    }
    if (_currentTrack != null) {
      _prefetchNextTrack();
    }
    // Spotify gets the songs in their new order.
    _scheduleSpotifyListRefresh();
    notifyListeners();
  }

  // ── Smart shuffle ──

  static const _avoidArtistKey = 'tsuki_shuffle_avoid_artist';
  static const _energyKey = 'tsuki_shuffle_energy';
  static const _recoEveryKey = 'tsuki_shuffle_reco_every';

  /// Recommendations are slipped in (the shuffle button's third state).
  bool _smartShuffle = false;
  ShuffleEnergy _energy = ShuffleEnergy.alternate;
  int _recoEvery = 3;
  // Middle tempo of the queue, splitting "fast" from "calm" songs.
  double? _bpmMedian;
  int _tempoGeneration = 0;
  SongRadio? _recoRadio;
  String? _recoSteeredBy;
  bool _recoLoading = false;

  /// Whether a song is the user's (listened, favourite, in a playlist):
  /// those are never recommended.
  bool Function(String trackId)? isInLibrary;

  ShuffleMode get shuffleMode => !_q.isShuffle
      ? ShuffleMode.off
      : (_smartShuffle ? ShuffleMode.smart : ShuffleMode.on);
  bool get avoidSameArtist => _q.avoidSameArtist;
  ShuffleEnergy get shuffleEnergy => _energy;

  /// One recommended song after every this many of the user's.
  int get recommendEvery => _recoEvery;
  bool isRecommended(String trackId) => _q.isRecommended(trackId);

  /// Why a recommended song is there ("because you're playing X").
  RadioReason? recommendationReasonFor(String trackId) =>
      _q.isRecommended(trackId) ? _recoRadio?.reasonFor(trackId) : null;

  /// The shuffle button: off, shuffle, shuffle with recommendations.
  ShuffleMode cycleShuffle() {
    setShuffleMode(switch (shuffleMode) {
      ShuffleMode.off => ShuffleMode.on,
      ShuffleMode.on => ShuffleMode.smart,
      ShuffleMode.smart => ShuffleMode.off,
    });
    return shuffleMode;
  }

  void setShuffleMode(ShuffleMode mode) {
    if (mode == shuffleMode) return;
    if ((mode != ShuffleMode.off) != _q.isShuffle) toggleShuffle();
    if (mode == ShuffleMode.off) return;
    _smartShuffle = mode == ShuffleMode.smart;
    _applyShuffleSettings();
    if (_smartShuffle) {
      unawaited(_topUpRecommendations(reshuffle: true));
    } else if (_q.dropRecommendations()) {
      _recoRadio = null;
      _queueChanged();
    }
    notifyListeners();
  }

  Future<void> setAvoidSameArtist(bool value) async {
    _q.avoidSameArtist = value;
    _reshuffleForNewSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_avoidArtistKey, value);
    } catch (_) {}
  }

  Future<void> setShuffleEnergy(ShuffleEnergy value) async {
    _energy = value;
    _applyShuffleSettings();
    _reshuffleForNewSettings();
    unawaited(_learnShuffleTempos());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_energyKey, value.index);
    } catch (_) {}
  }

  Future<void> setRecommendEvery(int value) async {
    _recoEvery = value.clamp(1, 10);
    _applyShuffleSettings();
    _reshuffleForNewSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_recoEveryKey, _recoEvery);
    } catch (_) {}
  }

  Future<void> _loadShuffleSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _q.avoidSameArtist = prefs.getBool(_avoidArtistKey) ?? true;
      final e = prefs.getInt(_energyKey);
      if (e != null && e >= 0 && e < ShuffleEnergy.values.length) {
        _energy = ShuffleEnergy.values[e];
      }
      _recoEvery = (prefs.getInt(_recoEveryKey) ?? 3).clamp(1, 10);
    } catch (_) {}
    _applyShuffleSettings();
  }

  void _applyShuffleSettings() {
    _q.flowScore = _energy == ShuffleEnergy.free ? null : _flowScore;
    _q.recommendEvery = _smartShuffle ? _recoEvery : 0;
  }

  /// Settings changed: what comes after the next song follows them now.
  void _reshuffleForNewSettings() {
    _q.reshuffleAhead();
    _queueChanged();
  }

  /// Extra score for [next] following [prev], by tempo (folded into one
  /// octave, like running mode: 70 and 140 BPM feel the same).
  double _flowScore(Track prev, Track next) {
    final a = BpmService.shared.cached(prev.id);
    final b = BpmService.shared.cached(next.id);
    if (a == null || b == null || a <= 0 || b <= 0) return 0;
    final from = BpmFlow.feel(a);
    final to = BpmFlow.feel(b);
    switch (_energy) {
      case ShuffleEnergy.free:
        return 0;
      case ShuffleEnergy.smooth:
        return 0.8 * (1 - ((from - to).abs() / 25).clamp(0.0, 1.0));
      case ShuffleEnergy.alternate:
        final mid = _bpmMedian ?? 120;
        final crosses = from >= mid ? to < mid : to >= mid;
        if (!crosses) return -0.3;
        return 0.5 + 0.3 * ((to - mid).abs() / 25).clamp(0.0, 1.0);
    }
  }

  /// Looks up the queue's tempos (cached after the first time) for the
  /// energy flow, then reorders the songs not yet handed on.
  Future<void> _learnShuffleTempos() async {
    if (!_q.isShuffle || _energy == ShuffleEnergy.free || !_online) return;
    final gen = ++_tempoGeneration;
    final tracks = _q.tracks.take(300).toList();
    final Map<String, double> bpms;
    try {
      bpms = await BpmService.shared.lookup(tracks, concurrency: 2);
    } catch (e) {
      debugPrint('[AudioProvider] Tempo lookup failed: $e');
      return;
    }
    if (gen != _tempoGeneration || !_q.isShuffle) return;
    final feels = [for (final b in bpms.values) if (b > 0) BpmFlow.feel(b)]
      ..sort();
    if (feels.isEmpty) return;
    _bpmMedian = feels[feels.length ~/ 2];
    // Keep what Spotify already has (no restart); reorder the rest.
    final spotify = _useSpotify && _spotifyActive && !_spotifyFallbackActive;
    _q.reshuffleAhead(keep: spotify ? _spotifyAhead.length + 1 : 1);
    _prefetchNextTrack();
    _persistPlaybackState();
    notifyListeners();
  }

  /// Keeps a few recommended songs waiting: like what's playing, and never
  /// one the user already has.
  Future<void> _topUpRecommendations({bool reshuffle = false}) async {
    final seed = _currentTrack;
    if (!_smartShuffle || !_q.isShuffle || seed == null || !_online) return;
    if (_recoLoading || _q.recommendationsLeft >= 3) return;
    _recoLoading = true;
    try {
      final radio = _recoRadio ??=
          AudioRadioController.radioFactory(seed, RadioMode.balanced)
            ..markQueued(_q.tracks);
      if (_recoSteeredBy != seed.id) {
        _recoSteeredBy = seed.id;
        if (seed.id != radio.seed.id) radio.moreLikeThis(seed);
      }
      final batch = await radio.nextBatch(count: 6);
      if (!identical(radio, _recoRadio) || !_smartShuffle) return;
      final fresh = [
        for (final t in batch)
          if (!(isInLibrary?.call(t.id) ?? false)) t
      ];
      if (_q.addRecommendations(fresh) == 0) return;
      debugPrint('[AudioProvider] ${fresh.length} recommended songs ready');
      if (reshuffle) _q.reshuffleAhead();
      _queueChanged();
    } catch (e) {
      debugPrint('[AudioProvider] Recommendations failed: $e');
    } finally {
      _recoLoading = false;
    }
  }

  void toggleRepeat() {
    _q.cycleRepeatMode();
    if (_q.isAtEnd) _prefetchNextTrack();
    _onRepeatChanged();
    notifyListeners();
  }
  void toggleLoop() => toggleRepeat();

  void setRepeatMode(PlaybackRepeatMode mode) {
    if (_q.repeatMode == mode) return;
    _q.setRepeatMode(mode);
    if (_q.isAtEnd) _prefetchNextTrack();
    _onRepeatChanged();
    notifyListeners();
  }

  /// With Spotify, repeat-one is Spotify looping the song; leaving it,
  /// Spotify needs our next songs to go on.
  void _onRepeatChanged() {
    if (!_useSpotify || !_spotifyActive || _spotifyFallbackActive) return;
    unawaited(_syncSpotifyRepeat());
    if (_spotifyAhead.isEmpty) unawaited(_reissueSpotifyAhead());
  }
  /// Reorders the playback queue from [oldIndex] to [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _q.length) return;
    if (newIndex < 0 || newIndex >= _q.length) return;
    _q.reorder(oldIndex, newIndex);
    _queueChanged();
  }

  /// Up to [max] upcoming queue indices, in the order they will play
  /// (shuffle included: the songs [next] will pick, in that order).
  List<int> upcomingOrder([int max = 60]) => _q.upcoming(max);

  /// How many songs are still to come (all the others when shuffling).
  int get upcomingCount => _q.upcomingCount;

  /// Queue indices already played, oldest first.
  List<int> get playedIndices => _q.played();

  /// Moves the song at position [from] of [upcomingOrder] to [to]. Dropped
  /// among the songs you queued, it joins them; past them, it leaves them.
  void moveUpcoming(int from, int to) {
    _q.moveUpcoming(from, to);
    _queueChanged();
  }

  /// Moves the queue song at [index] to play right after the current one.
  void playNextFromQueue(int index) {
    if (index < 0 || index >= _q.length) return;
    playNext(_q.tracks[index]);
  }

  /// The queue as it is now, to undo an edit with [restoreQueue].
  QueueSnapshot queueSnapshot() => _q.snapshot();

  /// Undoes edits made since [snapshot], keeping the song playing now.
  bool restoreQueue(QueueSnapshot snapshot) {
    if (!_q.restoreSnapshot(snapshot)) return false;
    _queueChanged();
    return true;
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
  @override
  void playNext(Track track, {bool userQueued = true}) {
    if (!_q.insertNext(track, userQueued: userQueued)) return;
    _queueChanged();
  }

  /// Queues tracks after the current one and anything queued before them,
  /// ahead of the rest of the album or playlist, like Spotify's queue.
  @override
  void addToQueue(Track track) => addAllToQueue([track]);
  @override
  void addAllToQueue(List<Track> tracks) {
    if (_q.enqueue(tracks) == 0) return;
    _queueChanged();
  }

  void _queueChanged() {
    _prefetchedTargetTrackId = null;
    _prefetchNextTrack();
    _persistPlaybackState();
    _scheduleSpotifyListRefresh();
    notifyListeners();
  }
  /// Removes the track at [index] from the playback queue.
  @override
  void removeFromQueue(int index) {
    if (index < 0 || index >= _q.length) return;
    final wasCurrent = _q.removeAt(index);

    if (_q.isEmpty) {
      stop();
      return;
    }

    if (wasCurrent) {
      playTrack(_q.tracks[_q.currentIndex]);
      _persistPlaybackState();
    } else {
      _queueChanged();
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
    _scheduleSpotifyListRefresh();
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
    final sinceStart = DateTime.now().difference(_lastPlayStart);
    if (sinceStart < const Duration(seconds: 3)) {
      // Usually a stale "completed" from the song before. But a song that
      // really ended this fast (a broken preview) sends no second event and
      // the queue would stall in silence: look again once the window passed.
      if (!_spotifyActive) {
        final gen = _playGeneration;
        _completionRecheck?.cancel();
        _completionRecheck = Timer(
            const Duration(seconds: 3) - sinceStart + const Duration(milliseconds: 100), () {
          if (gen != _playGeneration || _completionHandled || _spotifyActive) return;
          if (_service.player.processingState == ProcessingState.completed) {
            _handleTrackCompleted();
          }
        });
      }
      return;
    }
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
      } else if (finished != null && _mayContinueWithSimilar) {
        // Nothing queued in time: go on with similar songs now.
        unawaited(_radioCtrl
            .continueFrom(finished)
            .then((added) => added ? next() : stop()));
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

  @override
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
    _completionRecheck?.cancel();
    _spotifyListTimer?.cancel();
    _mediaTopTimer?.cancel();
    _unplugSub?.cancel();
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
