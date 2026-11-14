

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
      _modesSnapshot(),
    );
  }

  /// Shuffle (its state too: the songs heard this round, the recommended
  /// ones, the picks ahead) and repeat. Without it a closed app came back
  /// with shuffle off, playing the rest of the list in order.
  Map<String, dynamic> _modesSnapshot() => {
        'shuffle': shuffleMode.name,
        'repeat': _q.repeatMode.name,
        if (_q.isShuffle) ...{
          'heard': _q.heardIds.toList(),
          'recommended': _q.recommendedIds,
          'picks': [for (final i in _q.peekUpcoming(AudioProvider._spotifyAheadMax)) _q.tracks[i].id],
        },
      };

  /// Puts back the shuffle and repeat saved with the queue.
  void _applySavedModes(Map<String, dynamic>? modes) {
    if (modes == null) return;
    final shuffle = ShuffleMode.values.asNameMap()[modes['shuffle']] ?? ShuffleMode.off;
    final repeat = PlaybackRepeatMode.values.asNameMap()[modes['repeat']];
    if (repeat != null) _q.setRepeatMode(repeat);
    List<String> ids(Object? raw) => raw is List ? [for (final e in raw) e.toString()] : const [];
    _q.restoreShuffle(
      on: shuffle != ShuffleMode.off,
      heard: ids(modes['heard']),
      recommended: ids(modes['recommended']),
      picks: ids(modes['picks']),
    );
    _smartShuffle = shuffle == ShuffleMode.smart;
    _applyShuffleSettings();
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

      _q.restore(plan.queue, plan.savedIndex);
      _applySavedModes(plan.modes);
      var track = plan.track;
      if (plan.advanced && plan.savedIndex != plan.index) {
        // The saved song ended while the app was closed: on to the next
        // one as the queue plays it (a shuffle pick, with shuffle).
        final step = _q.next(online: _online, canPlay: _canPlayOffline);
        if (step.kind == QueueStepKind.play) track = _q.tracks[step.index];
      }
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
