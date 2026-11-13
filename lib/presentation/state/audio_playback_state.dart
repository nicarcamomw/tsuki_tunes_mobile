

part of 'audio_provider.dart';

// Saves the queue, position and radio so a killed app comes back where it was,
// and restores them on start.
extension _PlaybackState on AudioProvider {
  /// Saves the position every ~10 s so a killed app resumes close to where
  /// it stopped instead of at the start of the track.
  void _maybePersistPosition() {
    final now = DateTime.now();
    if (now.difference(_lastPositionPersist).inSeconds < 10) return;
    _lastPositionPersist = now;
    _persistPlaybackState();
  }

  /// Saves shortly (changes in a row are written once).
  void _persistPlaybackState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), _savePlaybackStateNow);
  }

  /// Saves right away: going to the background, where the system may kill
  /// the app before a delayed save runs.
  Future<void> _savePlaybackStateNow() async {
    _persistTimer?.cancel();
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
  }

  Map<String, dynamic>? _radioSnapshot() =>
      _radioCtrl.snapshot(_q.tracks.map((t) => t.id));

  Future<void> _restorePlaybackState() async {
    try {
      final state = await _storage.getPlaybackState();
      if (state == null) return;

      if (_currentTrack != null || !_q.isEmpty || _isPlaying) return;

      // What to bring back is decided by planPlaybackRestore (pure, tested);
      // here it's only applied.
      final plan = planPlaybackRestore(state, DateTime.now());
      if (plan == null) return;
      final track = plan.track;

      _q.restore(plan.queue, plan.index);
      _currentTrack = track;
      _setPosition(plan.position);
      _duration = Duration(seconds: track.durationSeconds > 0 ? track.durationSeconds : 30);
      _isPlaying = false;
      _isBuffering = false;

      if (plan.advanced) {
        _prefetchNextTrack();
        notifyListeners();
        _log.fine('The saved song would have ended during background; advanced to "${track.title}"');
        return;
      }

      final radio = plan.radio;
      if (radio != null) _radioCtrl.restoreFrom(radio, plan.queue);

      _prefetchNextTrack();
      notifyListeners();
      // Make sure the restored radio has songs lined up before they're due.
      if (_radioCtrl.isActive) unawaited(_radioCtrl.topUp());
      _log.fine('Restored playback state: "${track.title}" at ${plan.position.inMilliseconds}ms (${_q.length} tracks in queue${_radioCtrl.isActive ? ', radio on' : ''})');
    } catch (e) {
      _log.severe('Error restoring playback state: $e');
    }
  }
}
