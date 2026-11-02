part of 'audio_provider.dart';

// Keeps the system media notification, lock screen, Android Auto and the home
// screen widget in step with what AudioProvider is playing (or the ambient
// mixer, when no song is loaded).
extension _MediaSession on AudioProvider {
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
    handler.isSpotifyPlaying =
        () => _useSpotify && _spotifyActive && !_spotifyFallbackActive;
  }

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
    // The system moves the lock-screen bar on its own from the last pushed
    // position and speed; when ours moved elsewhere (a Spotify resync, a
    // speed ramp) push again, or the bar drifts from the song.
    final speed = _spotifyActive && !_spotifyFallbackActive ? 1.0 : _service.speed;
    final now = DateTime.now();
    final expected = _isPlaying
        ? _mediaPostedPosition +
            (now.difference(_mediaPostedAt) * _mediaPostedSpeed)
        : _mediaPostedPosition;
    final drifted = (expected - _position).abs() > const Duration(seconds: 2) ||
        (speed - _mediaPostedSpeed).abs() > 0.01;
    if (!force && !drifted && stateKey == _mediaStateKey) return;
    _mediaStateKey = stateKey;
    _mediaPostedPosition = _position;
    _mediaPostedAt = now;
    _mediaPostedSpeed = speed;
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
      speed: speed,
    ));
  }

  /// With Spotify, Android also shows Spotify's own player and puts first
  /// the one that updated last, so tapping it would open Spotify. Posting
  /// Tsuki's state again just after Spotify updates its own (any change it
  /// reports, a pause included) keeps Tsuki's on top. Every half second for
  /// 5 s after Spotify's latest change: as a song starts Spotify updates its
  /// own several times (buffering, artwork, playing), and a wait restarted
  /// by each of them left Spotify's card first for those seconds. Only the
  /// card is posted again; playback is untouched.
  void _keepMediaSessionOnTop() {
    _mediaTopUntil = DateTime.now().add(const Duration(seconds: 5));
    if (_mediaTopTimer?.isActive ?? false) return;
    _mediaTopTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final spotifyPlayer =
          _useSpotify && _spotifyActive && _currentTrack != null;
      if (!spotifyPlayer || DateTime.now().isAfter(_mediaTopUntil)) {
        timer.cancel();
        return;
      }
      _syncMediaSession(force: true);
    });
    _startMediaSessionHeartbeat();
  }

  /// A slow heartbeat that re-posts Tsuki's media session every 10 seconds
  /// while Spotify is playing. Without it, Spotify's own media session
  /// becomes "most recent" after the 5-second burst ends, and car/Bluetooth
  /// controls (steering wheel next/prev) go to Spotify instead of Tsuki.
  void _startMediaSessionHeartbeat() {
    if (_mediaHeartbeatTimer?.isActive ?? false) return;
    _mediaHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      final spotifyPlayer =
          _useSpotify && _spotifyActive && _isPlaying && _currentTrack != null;
      if (!spotifyPlayer) {
        timer.cancel();
        return;
      }
      _syncMediaSession(force: true);
    });
  }
}
