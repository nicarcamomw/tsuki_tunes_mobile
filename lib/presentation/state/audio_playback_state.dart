

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

      final rawQueue = state['queue'];
      final rawIndex = state['currentIndex'];
      final rawPosMs = state['position'];

      if (rawQueue is! List || rawQueue.isEmpty) return;

      final restoredQueue = <Track>[];
      for (final item in rawQueue) {
        if (item is Map) {
          restoredQueue.add(Track.fromJson(Map<String, dynamic>.from(item)));
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
          _log.fine('Track "${restoredTrack.title}" would have ended during background; advanced to "${nextTrack.title}"');
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
      _log.fine('Restored playback state: "${restoredTrack.title}" at ${posMs}ms (${_q.length} tracks in queue${_radioCtrl.isActive ? ', radio on' : ''})');
    } catch (e) {
      _log.severe('Error restoring playback state: $e');
    }
  }
}
