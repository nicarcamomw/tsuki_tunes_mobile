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

  /// With Spotify, Android also shows Spotify's own player and puts first
  /// the one that updated last. Posting Tsuki's state again just after
  /// Spotify updates its own (at each song start) keeps Tsuki's on top.
  void _keepMediaSessionOnTop() {
    _mediaTopTimer?.cancel();
    _mediaTopTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_useSpotify && _spotifyActive && _isPlaying) {
        _syncMediaSession(force: true);
      }
    });
  }
}
