part of 'audio_provider.dart';

mixin _RadioMixin on _AudioProviderBase {
  // ---------------------------------------------------------------------------
  // Radio lifecycle
  // ---------------------------------------------------------------------------

  Future<bool> startRadio(Track seed) async {
    await _loadRadioModePref();
    final radio = SongRadio(seed: seed, mode: _radioModePref);
    _radioTopUpFuture = null;
    _radioStatus = RadioStatus.loading;

    if (_currentTrack?.id == seed.id) {
      _radio = radio;
      _prefetchedTargetTrackId = null;
      _q.clear(keep: _currentTrack);
      _persistPlaybackState();
      notifyListeners();
    } else {
      final playing = playTrack(seed, newQueue: [seed]);
      _radio = radio;
      unawaited(playing);
    }

    final added = await _radioTopUp(force: true, count: 10);
    if (!added && identical(_radio, radio)) {
      _radio = null;
      _persistPlaybackState();
      notifyListeners();
    }
    return added;
  }

  void stopRadio() {
    if (_radio == null) return;
    _radio = null;
    _persistPlaybackState();
    notifyListeners();
  }

  Future<void> setRadioMode(RadioMode mode) async {
    _radioModePref = mode;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setInt(_radioModeKey, mode.index))
        .catchError((_) => false));
    final radio = _radio;
    if (radio == null || radio.mode == mode) {
      notifyListeners();
      return;
    }
    radio.setMode(mode);
    _persistPlaybackState();
    await _radioReplaceUpcoming(keep: 1);
  }

  // ---------------------------------------------------------------------------
  // Radio steering
  // ---------------------------------------------------------------------------

  Future<void> radioMoreLikeThis() async {
    final radio = _radio;
    final track = _currentTrack;
    if (radio == null || track == null) return;
    radio.moreLikeThis(track);
    await _radioReplaceUpcoming(keep: 1);
  }

  Future<void> radioLessLikeThis() async {
    final radio = _radio;
    final track = _currentTrack;
    if (radio == null || track == null) return;
    radio.lessLikeThis(track);
    if (!_q.isShuffle) {
      for (var i = _q.length - 1; i > _q.currentIndex; i--) {
        if (radio.isBanned(_q.tracks[i])) _q.removeAt(i);
      }
    }
    _prefetchedTargetTrackId = null;
    await _radioTopUp(force: true);
    await next();
  }

  // ---------------------------------------------------------------------------
  // Radio internals
  // ---------------------------------------------------------------------------

  Future<void> _loadRadioModePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final i = prefs.getInt(_radioModeKey);
      if (i != null && i >= 0 && i < RadioMode.values.length) {
        _radioModePref = RadioMode.values[i];
      }
    } catch (_) {}
  }

  @override
  void _radioRegisterLeaving(Track incoming, {bool completed = false}) {
    final radio = _radio;
    final leaving = _currentTrack;
    if (radio == null || leaving == null || leaving.id == incoming.id) return;
    final total = _duration.inMilliseconds;
    final fraction = completed
        ? 1.0
        : (total > 0
            ? (_position.inMilliseconds / total).clamp(0.0, 1.0)
            : 0.0);
    radio.registerPlayed(leaving, fraction);
  }

  int _radioRemaining() {
    if (_q.isShuffle) {
      final heard = {..._q.history, _q.currentIndex};
      return _q.length - heard.length;
    }
    return _q.length - _q.currentIndex - 1;
  }

  @override
  Future<bool> _radioTopUp({bool force = false, int count = 8}) {
    if (_radio == null) return Future.value(false);
    if (!force && _radioRemaining() >= _radioLowWater) {
      return Future.value(true);
    }
    return _radioTopUpFuture ??=
        _doRadioTopUp(count).whenComplete(() => _radioTopUpFuture = null);
  }

  Future<bool> _doRadioTopUp(int count) async {
    final radio = _radio;
    if (radio == null) return false;
    _radioStatus = RadioStatus.loading;
    notifyListeners();

    List<Track> batch;
    try {
      batch = await radio.nextBatch(count: count);
    } catch (e) {
      debugPrint('[AudioProvider] radio refill failed: $e');
      batch = const [];
    }
    if (!identical(_radio, radio)) return false;

    final added = _q.append(batch);
    _trimRadioHistory();
    _radioStatus = added > 0
        ? RadioStatus.ready
        : (_online ? RadioStatus.exhausted : RadioStatus.offline);
    if (added > 0) {
      _prefetchNextTrack();
      _persistPlaybackState();
    }
    notifyListeners();
    return added > 0;
  }

  void _trimRadioHistory() {
    if (_q.isShuffle || _q.length <= _radioMaxQueue) return;
    final drop = _q.currentIndex - 30;
    if (drop > 0) _q.dropBefore(drop);
  }

  Future<void> _radioReplaceUpcoming({required int keep}) async {
    final radio = _radio;
    if (radio == null) return;
    if (!_q.isShuffle) {
      final firstReplaceable = _q.currentIndex + 1 + keep;
      for (var i = _q.length - 1; i >= firstReplaceable; i--) {
        final reason = radio.reasonFor(_q.tracks[i].id);
        if (reason != null && reason.source != RadioSource.seed) {
          _q.removeAt(i);
        }
      }
    }
    _prefetchedTargetTrackId = null;
    notifyListeners();
    await _radioTopUp(force: true);
  }

  @override
  Map<String, dynamic>? _radioSnapshot() =>
      _radio?.toJson(keepReasonsFor: _q.tracks.map((t) => t.id));
}
