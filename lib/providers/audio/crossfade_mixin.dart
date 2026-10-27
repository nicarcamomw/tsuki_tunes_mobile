part of 'audio_provider.dart';

mixin _CrossfadeMixin on _AudioProviderBase {
  // ---------------------------------------------------------------------------
  // Crossfade detection
  // ---------------------------------------------------------------------------

  @override
  void _checkCrossfade(Duration pos) {
    if (_q.repeatMode == PlaybackRepeatMode.one) return;
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered) return;
    if (_useSpotify && !_spotifyFallbackActive) return;
    if (_stopAfterCurrentTrack) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (pos.inSeconds < 2) return;

    final remaining = _duration - pos;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerCrossfade();
    }
  }

  @override
  void _checkSpotifyCrossfade() {
    if (_q.repeatMode == PlaybackRepeatMode.one) return;
    if (_crossfadeSeconds <= 0 || _crossfadeTriggered) return;
    if (_stopAfterCurrentTrack) return;
    if (_duration <= Duration(seconds: _crossfadeSeconds)) return;
    if (_position.inSeconds < 2) return;

    final remaining = _duration - _position;
    if (remaining <= Duration(seconds: _crossfadeSeconds)) {
      _triggerSpotifyCrossfade();
    }
  }

  // ---------------------------------------------------------------------------
  // Crossfade triggers
  // ---------------------------------------------------------------------------

  Future<void> _triggerSpotifyCrossfade() async {
    if (_q.isEmpty || _crossfadeTriggered) return;

    final nextIdx = _q.advanceForCrossfade();
    if (nextIdx == null) return;

    _crossfadeTriggered = true;
    final nextTrack = _q.tracks[nextIdx];
    debugPrint('[AudioProvider] Spotify crossfade to "${nextTrack.title}" '
        '(${_crossfadeSeconds}s before end)');

    _radioRegisterLeaving(nextTrack, completed: true);
    _currentTrack = nextTrack;
    _position = Duration.zero;
    _duration = Duration(
        seconds: nextTrack.durationSeconds > 0 ? nextTrack.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;

    notifyListeners();
    onTrackStarted?.call(nextTrack);
    _prefetchNextTrack();
    unawaited(_radioTopUp());

    try {
      await _playViaSpotify(nextTrack);
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    } catch (e) {
      debugPrint('[AudioProvider] Spotify crossfade error: $e');
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    }
  }

  Future<void> _triggerCrossfade() async {
    if (_q.isEmpty || _crossfadeTriggered) return;

    final nextIdx = _q.advanceForCrossfade();
    if (nextIdx == null) return;

    _crossfadeTriggered = true;
    final nextTrack = _q.tracks[nextIdx];
    _radioRegisterLeaving(nextTrack, completed: true);
    _currentTrack = nextTrack;
    _position = Duration.zero;
    _duration = Duration(
        seconds: nextTrack.durationSeconds > 0 ? nextTrack.durationSeconds : 30);
    _lastPlayStart = DateTime.now();
    final gen = ++_playGeneration;
    _completionHandled = false;

    debugPrint('[AudioProvider] Starting crossfade to "${nextTrack.title}" '
        '(${_crossfadeSeconds}s)');
    notifyListeners();
    onTrackStarted?.call(nextTrack);
    _prefetchNextTrack();
    unawaited(_radioTopUp());

    try {
      final freshNext = await _withFreshPreview(nextTrack);
      if (gen != _playGeneration) return;
      await _service.crossfadeTo(freshNext, _crossfadeSeconds);
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
    } catch (e) {
      debugPrint(
          '[AudioProvider] Crossfade error, falling back to normal play: $e');
      if (gen != _playGeneration) return;
      _crossfadeTriggered = false;
      try {
        await _service.playTrack(nextTrack);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Testing helpers
  // ---------------------------------------------------------------------------

  @visibleForTesting
  bool get crossfadeTriggered => _crossfadeTriggered;

  @visibleForTesting
  void checkCrossfade(Duration pos) => _checkCrossfade(pos);
}
