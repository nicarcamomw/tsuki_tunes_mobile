part of 'audio_provider.dart';

// Full-song playback through Spotify (Web API and App Remote): starting songs,
// following Spotify through the queue it was handed, keeping position in sync,
// and falling back to the Deezer preview when it cannot play.
extension _SpotifyPlayback on AudioProvider {
  static const int _aheadMax = 8;

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
      for (final i in _q.peekUpcoming(_aheadMax)) _q.tracks[i],
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
    final idx = AudioProvider.queueIndexMatching(_q.tracks, name, artists,
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
}
