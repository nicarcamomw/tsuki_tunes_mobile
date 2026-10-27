import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/playback_queue.dart';
import '../services/song_radio.dart';

export '../services/song_radio.dart' show RadioMode, RadioReason, RadioSource;

enum RadioStatus { loading, ready, offline, exhausted }

class AudioRadioController {
  final PlaybackQueue _q;
  final VoidCallback _onStateChanged;
  final Future<void> Function() _persistPlaybackState;
  final bool Function() _isOnline;

  SongRadio? _radio;
  RadioStatus _status = RadioStatus.ready;
  RadioMode _modePref = RadioMode.balanced;
  Future<bool>? _topUpFuture;
  static const int _lowWater = 4;
  static const int _maxQueue = 150;
  static const String _modeKey = 'tsuki_radio_mode';

  AudioRadioController({
    required PlaybackQueue queue,
    required VoidCallback onStateChanged,
    required Future<void> Function() persistPlaybackState,
    required bool Function() isOnline,
  })  : _q = queue,
        _onStateChanged = onStateChanged,
        _persistPlaybackState = persistPlaybackState,
        _isOnline = isOnline;

  bool get isActive => _radio != null;
  Track? get seed => _radio?.seed;
  RadioMode get mode => _radio?.mode ?? _modePref;
  RadioStatus get status => _status;
  bool get usesLastFm => _radio?.usesLastFm ?? false;
  RadioReason? reasonFor(String trackId) => _radio?.reasonFor(trackId);
  RadioMode get modePref => _modePref;

  set radio(SongRadio? r) => _radio = r;
  SongRadio? get radio => _radio;

  Map<String, dynamic>? snapshot(Iterable<String> trackIds) =>
      _radio?.toJson(keepReasonsFor: trackIds);

  void restoreFrom(Map<String, dynamic> raw, List<Track> queue) {
    final radio = SongRadio.fromJson(raw);
    if (radio != null) {
      radio.markQueued(queue);
      _radio = radio;
      _modePref = radio.mode;
      _status = RadioStatus.ready;
    }
  }

  Future<bool> start(
    Track seed, {
    required Track? currentTrack,
    required Future<void> Function(Track, {List<Track>? newQueue}) playTrack,
    required void Function() clearQueue,
  }) async {
    await _loadModePref();
    final radio = SongRadio(seed: seed, mode: _modePref);
    _topUpFuture = null;
    _status = RadioStatus.loading;

    if (currentTrack?.id == seed.id) {
      _radio = radio;
      clearQueue();
      _onStateChanged();
    } else {
      final playing = playTrack(seed, newQueue: [seed]);
      _radio = radio;
      unawaited(playing);
    }

    final added = await topUp(force: true, count: 10);
    if (!added && identical(_radio, radio)) {
      _radio = null;
      unawaited(_persistPlaybackState());
      _onStateChanged();
    }
    return added;
  }

  void stop() {
    if (_radio == null) return;
    _radio = null;
    unawaited(_persistPlaybackState());
    _onStateChanged();
  }

  Future<void> setMode(RadioMode m) async {
    _modePref = m;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setInt(_modeKey, m.index))
        .catchError((_) => false));
    final radio = _radio;
    if (radio == null || radio.mode == m) {
      _onStateChanged();
      return;
    }
    radio.setMode(m);
    unawaited(_persistPlaybackState());
    await replaceUpcoming(keep: 1);
  }

  Future<void> moreLikeThis(Track track) async {
    final radio = _radio;
    if (radio == null) return;
    radio.moreLikeThis(track);
    await replaceUpcoming(keep: 1);
  }

  Future<void> lessLikeThis(
    Track track, {
    required Future<void> Function() next,
  }) async {
    final radio = _radio;
    if (radio == null) return;
    radio.lessLikeThis(track);
    if (!_q.isShuffle) {
      for (var i = _q.length - 1; i > _q.currentIndex; i--) {
        if (radio.isBanned(_q.tracks[i])) _q.removeAt(i);
      }
    }
    await topUp(force: true);
    await next();
  }

  void registerLeaving(Track incoming, Track? current, Duration position,
      Duration duration, {bool completed = false}) {
    final radio = _radio;
    if (radio == null || current == null || current.id == incoming.id) return;
    final total = duration.inMilliseconds;
    final fraction = completed
        ? 1.0
        : (total > 0 ? (position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0);
    radio.registerPlayed(current, fraction);
  }

  int _remaining() {
    if (_q.isShuffle) {
      final heard = {..._q.history, _q.currentIndex};
      return _q.length - heard.length;
    }
    return _q.length - _q.currentIndex - 1;
  }

  Future<bool> topUp({bool force = false, int count = 8}) {
    if (_radio == null) return Future.value(false);
    if (!force && _remaining() >= _lowWater) return Future.value(true);
    return _topUpFuture ??=
        _doTopUp(count).whenComplete(() => _topUpFuture = null);
  }

  Future<bool> _doTopUp(int count) async {
    final radio = _radio;
    if (radio == null) return false;
    _status = RadioStatus.loading;
    _onStateChanged();

    List<Track> batch;
    try {
      batch = await radio.nextBatch(count: count);
    } catch (e) {
      debugPrint('[AudioRadio] refill failed: $e');
      batch = const [];
    }
    if (!identical(_radio, radio)) return false;

    final added = _q.append(batch);
    _trimHistory();
    _status = added > 0
        ? RadioStatus.ready
        : (_isOnline() ? RadioStatus.exhausted : RadioStatus.offline);
    if (added > 0) {
      unawaited(_persistPlaybackState());
    }
    _onStateChanged();
    return added > 0;
  }

  void _trimHistory() {
    if (_q.isShuffle || _q.length <= _maxQueue) return;
    final drop = _q.currentIndex - 30;
    if (drop > 0) _q.dropBefore(drop);
  }

  Future<void> replaceUpcoming({required int keep}) async {
    final radio = _radio;
    if (radio == null) return;
    if (!_q.isShuffle) {
      final firstReplaceable = _q.currentIndex + 1 + keep;
      for (var i = _q.length - 1; i >= firstReplaceable; i--) {
        final reason = radio.reasonFor(_q.tracks[i].id);
        if (reason != null && reason.source != RadioSource.seed) _q.removeAt(i);
      }
    }
    _onStateChanged();
    await topUp(force: true);
  }

  Future<void> _loadModePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final i = prefs.getInt(_modeKey);
      if (i != null && i >= 0 && i < RadioMode.values.length) {
        _modePref = RadioMode.values[i];
      }
    } catch (_) {}
  }
}
