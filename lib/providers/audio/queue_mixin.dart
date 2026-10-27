part of 'audio_provider.dart';

mixin _QueueMixin on _AudioProviderBase {
  // ---------------------------------------------------------------------------
  // Queue navigation
  // ---------------------------------------------------------------------------

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

  @override
  Future<void> next() =>
      _applyStep(_q.next(online: _online, canPlay: _canPlayOffline));

  @override
  Future<void> previous() => _applyStep(_q.previous(
        position: _position,
        online: _online,
        canPlay: _canPlayOffline,
      ));

  // ---------------------------------------------------------------------------
  // Shuffle & repeat
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Queue manipulation
  // ---------------------------------------------------------------------------

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

  void clearQueue() {
    _prefetchedUri = null;
    _prefetchedForTrackId = null;
    _prefetchedTargetTrackId = null;
    _q.clear(keep: _currentTrack);
    _persistPlaybackState();
    notifyListeners();
    unawaited(_radioTopUp());
  }

  // ---------------------------------------------------------------------------
  // Track completion
  // ---------------------------------------------------------------------------

  @visibleForTesting
  Future<void> handleTrackCompletedForTesting() async {
    _completionHandled = false;
    _crossfadeTriggered = false;
    _lastPlayStart = DateTime.now().subtract(const Duration(seconds: 10));
    _handleTrackCompleted();
    await Future.delayed(Duration.zero);
  }

  @override
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
        unawaited(
            _radioTopUp(force: true).then((added) => added ? next() : stop()));
      } else {
        stop();
      }
    } else {
      next();
    }
  }
}
