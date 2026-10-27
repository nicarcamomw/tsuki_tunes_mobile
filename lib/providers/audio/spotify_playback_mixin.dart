part of 'audio_provider.dart';

mixin _SpotifyPlaybackMixin on _AudioProviderBase {
  // ---------------------------------------------------------------------------
  // Spotify init
  // ---------------------------------------------------------------------------

  @override
  void _initSpotify() {
    if (!_spotify.isConnected) return;
    _useSpotify = _spotify.isPremium;
    if (_useSpotify) _warmUpSpotifyDevice();
  }

  void _warmUpSpotifyDevice() {
    final token = _spotify.accessToken;
    if (token == null) return;
    _nativePlayer.connect(accessToken: token).then((ok) {
      if (ok) debugPrint('Spotify: App Remote connected for device warm-up');
    }).catchError((e) {
      debugPrint('Spotify: warm-up connect error (non-fatal): $e');
    });
  }

  @override
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

  // ---------------------------------------------------------------------------
  // Audio session (interruption handling for Spotify)
  // ---------------------------------------------------------------------------

  @override
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

  // ---------------------------------------------------------------------------
  // Position timer & state sync
  // ---------------------------------------------------------------------------

  int _spotifyPollTick = 0;

  @override
  void _startPositionTimer() {
    _spotifyPositionTimer?.cancel();
    _spotifyPollTick = 0;
    _spotifyPositionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _onPositionTick(),
    );
  }

  @override
  void _stopPositionTimer() {
    _spotifyPositionTimer?.cancel();
    _spotifyPositionTimer = null;
  }

  void _onPositionTick() {
    if (!_spotifyActive || !_isPlaying) return;

    if (_nativePlayer.isConnected && _currentSpotifyUri != null) {
      final nativePos = _nativePlayer.currentPosition;
      if (nativePos != null) {
        _position = nativePos;
        _checkSpotifyCrossfade();
        _checkListenedThreshold();
        _checkPlayCounted();
        _maybePersistPosition();
        notifyListeners();
        _spotifyPollTick++;
        if (_spotifyPollTick % 30 == 0) _syncSpotifyPlaybackState();
        return;
      }
    }

    final elapsed = DateTime.now().difference(_spotifySyncTime);
    _position = _spotifySyncPosition + elapsed;
    if (_position > _duration) _position = _duration;
    _checkSpotifyCrossfade();
    _checkListenedThreshold();
    _checkPlayCounted();
    _maybePersistPosition();
    notifyListeners();

    _spotifyPollTick++;
    if (_spotifyPollTick % 20 == 0) _syncSpotifyPlaybackState();
  }

  @override
  void _syncSpotifyPlaybackState() {
    _spotify.getPlaybackState().then((state) {
      if (!_spotifyActive) return;

      if (state == null) {
        if (_isPlaying &&
            DateTime.now().difference(_lastPlayCommandTime).inSeconds > 10) {
          debugPrint('[AudioProvider] Spotify lost active session, marking paused');
          _isPlaying = false;
          _stopPositionTimer();
          notifyListeners();
        }
        return;
      }

      final item = state['item'] as Map<String, dynamic>?;
      final linked = item?['linked_from'] as Map<String, dynamic>?;
      final currentUri = item?['uri'] as String?;
      final playingRemote = state['is_playing'] == true;
      final progressMs = state['progress_ms'] as int? ?? 0;
      final durationMs = item?['duration_ms'] as int? ?? 0;

      if (_currentSpotifyUri != null &&
          currentUri != null &&
          currentUri != _currentSpotifyUri &&
          linked?['uri'] != _currentSpotifyUri) {
        debugPrint('[AudioProvider] Spotify transferred to different track: $currentUri');
        _fallbackFromSpotify();
        return;
      }

      if (durationMs > 0) _duration = Duration(milliseconds: durationMs);
      _spotifySyncPosition = Duration(milliseconds: progressMs);
      _spotifySyncTime = DateTime.now();

      if (playingRemote != _isPlaying) {
        _isPlaying = playingRemote;
        if (_isPlaying) {
          _lastPlayCommandTime = DateTime.now();
          _startPositionTimer();
        } else {
          _stopPositionTimer();
        }
        notifyListeners();
      }
    }).catchError((e) {
      debugPrint('[AudioProvider] Spotify state poll error: $e');
    });
  }

  // ---------------------------------------------------------------------------
  // Spotify transport
  // ---------------------------------------------------------------------------

  @override
  Future<void> _spotifyPause() async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.pause();
        return;
      } catch (_) {}
    }
    await _spotify.pause();
  }

  @override
  Future<void> _spotifyResume() async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.resume();
        return;
      } catch (_) {}
    }
    await _spotify.resume();
  }

  @override
  Future<void> _spotifySeek(int ms) async {
    if (_nativePlayer.isConnected) {
      try {
        await _nativePlayer.seekTo(Duration(milliseconds: ms));
        return;
      } catch (_) {}
    }
    await _spotify.seek(ms);
  }

  // ---------------------------------------------------------------------------
  // Play via Spotify
  // ---------------------------------------------------------------------------

  @override
  Future<void> _playViaSpotify(Track track) async {
    final gen = _playGeneration;

    String? uri;
    if (_prefetchedForTrackId == track.id && _prefetchedUri != null) {
      uri = _prefetchedUri;
      debugPrint('Spotify: using prefetched URI for "${track.title}"');
    }
    _prefetchedUri = null;
    _prefetchedForTrackId = null;

    uri ??= await _resolveSpotifyUri(track);
    if (gen != _playGeneration) return;

    if (uri == null) {
      debugPrint('Spotify: no URI found for "${track.title}", falling back to preview');
      _lastSpotifyError = SpotifyFallbackReason.noUri;
      _spotifyActive = false;
      _spotifyFallbackActive = true;
      return;
    }

    _currentSpotifyUri = uri;

    bool played = false;
    if (_nativePlayer.isConnected) {
      try {
        played = await _nativePlayer.playUri(uri);
        if (gen != _playGeneration) return;
        debugPrint('Spotify: App Remote play result=$played');
      } catch (e) {
        debugPrint('Spotify: App Remote play error: $e');
      }
    }

    if (!played) {
      played = await _spotify.play(trackUri: uri);
      if (gen != _playGeneration) return;
      debugPrint('Spotify: Web API play result=$played');
    }

    if (!played) {
      debugPrint('Spotify: Web API play failed, trying ensureActiveDevice...');
      await _spotify.ensureActiveDevice();
      if (gen != _playGeneration) return;
      played = await _spotify.play(trackUri: uri);
      if (gen != _playGeneration) return;
      debugPrint('Spotify: retry with ensureActiveDevice result=$played');
    }

    if (!played) {
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

  // ---------------------------------------------------------------------------
  // Spotify verification & fallback
  // ---------------------------------------------------------------------------

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
      unawaited(SemanticsService.sendAnnouncement(
          view,
          'Spotify Premium not available, switching to preview',
          TextDirection.ltr));
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
      debugPrint(
          '[SpotifyCheck] Spotify device volume is 0%: playback is silent');
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

  @override
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
    debugPrint(
        '[AudioProvider] Spotify did not resume after interruption, marking paused');
    _isPlaying = false;
    _stopPositionTimer();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Spotify URI resolution & prefetching
  // ---------------------------------------------------------------------------

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

  @override
  void _prefetchNextTrack() {
    final nextIdx = _q.peekNext();
    if (nextIdx == null || nextIdx < 0 || nextIdx >= _q.length) return;

    final nextTrack = _q.tracks[nextIdx];

    _precache(nextTrack);

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
        debugPrint(
            '[AudioProvider] Prefetched Spotify URI for "${nextTrack.title}"');
      }).catchError((e) {
        if (gen == _prefetchGeneration) {
          _prefetchedTargetTrackId = null;
        }
        debugPrint('[AudioProvider] Spotify prefetch non-fatal error: $e');
      });
    }
  }
}
