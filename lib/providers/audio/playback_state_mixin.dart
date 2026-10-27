part of 'audio_provider.dart';

mixin _PlaybackStateMixin on _AudioProviderBase {
  // Mixin-local state for dedup
  String? _mediaItemKey;
  String? _mediaStateKey;
  String? _widgetTrackKey;
  bool? _widgetPlayingKey;
  DateTime _lastPositionPersist = DateTime(2000);

  // ---------------------------------------------------------------------------
  // Media session handler
  // ---------------------------------------------------------------------------

  @override
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

  @override
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

  @override
  void _syncHomeWidget() {
    final trackKey = _currentTrack?.id;
    final playingKey = _isPlaying;
    if (trackKey == _widgetTrackKey && playingKey == _widgetPlayingKey) return;
    _widgetTrackKey = trackKey;
    _widgetPlayingKey = playingKey;
    HomeWidgetService().updateTrack(_currentTrack, isPlaying: _isPlaying);
  }

  // ---------------------------------------------------------------------------
  // Persist / restore
  // ---------------------------------------------------------------------------

  @override
  void _maybePersistPosition() {
    final now = DateTime.now();
    if (now.difference(_lastPositionPersist).inSeconds < 10) return;
    _lastPositionPersist = now;
    _persistPlaybackState();
  }

  @override
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

  @override
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
          restoredQueue
              .add(Track.fromStorage(Map<String, dynamic>.from(item)));
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
        final radio =
            SongRadio.fromJson(Map<String, dynamic>.from(rawRadio));
        if (radio != null) {
          radio.markQueued(restoredQueue);
          _radio = radio;
          _radioModePref = radio.mode;
          _radioStatus = RadioStatus.ready;
        }
      }

      _prefetchNextTrack();
      notifyListeners();
      if (_radio != null) unawaited(_radioTopUp());
      debugPrint(
          '[AudioProvider] Restored playback state: "${restoredTrack.title}" '
          'at ${posMs}ms (${_q.length} tracks in queue'
          '${_radio != null ? ', radio on' : ''})');
    } catch (e) {
      debugPrint('[AudioProvider] Error restoring playback state: $e');
    }
  }

  @visibleForTesting
  Future<void> restorePlaybackStateForTesting() => _restorePlaybackState();
}
