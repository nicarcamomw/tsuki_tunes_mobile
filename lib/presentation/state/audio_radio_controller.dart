import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/lastfm_service.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/playback_queue.dart';
import '../../domain/logic/song_radio.dart';
import '../../core/logger.dart';


final _log = Log.named('AudioRadio');

export '../../domain/logic/song_radio.dart' show RadioMode, RadioReason, RadioSource;

enum RadioStatus { loading, ready, offline, exhausted }

class AudioRadioController {
  final PlaybackQueue _q;
  final VoidCallback _onStateChanged;
  final Future<void> Function() _persistPlaybackState;
  final bool Function() _isOnline;
  final VoidCallback? _onQueueGrew;

  SongRadio? radio;
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
    VoidCallback? onQueueGrew,
  })  : _q = queue,
        _onStateChanged = onStateChanged,
        _persistPlaybackState = persistPlaybackState,
        _isOnline = isOnline,
        _onQueueGrew = onQueueGrew;

  /// Makes the radios (and smart shuffle's recommendations); tests swap
  /// it for fake song sources.
  static SongRadio Function(Track seed, RadioMode mode) radioFactory =
      (seed, mode) => SongRadio(
            seed: seed,
            mode: mode,
            similar: LastFmService.getSimilarTracks,
            artistRadio: DeezerApiService().getArtistRadio,
            search: _searchCatalog,
            useLastFm: LastFmService.isConfigured,
          );

  static Future<List<Track>> _searchCatalog(String query) async {
    try {
      return await DeezerApiService().searchTracks(query, limit: 6);
    } catch (_) {
      return const [];
    }
  }

  bool get isActive => radio != null;
  Track? get seed => radio?.seed;
  RadioMode get mode => radio?.mode ?? _modePref;
  RadioStatus get status => _status;
  bool get usesLastFm => radio?.usesLastFm ?? false;
  RadioReason? reasonFor(String trackId) => radio?.reasonFor(trackId);
  RadioMode get modePref => _modePref;

  Map<String, dynamic>? snapshot(Iterable<String> trackIds) =>
      radio?.toJson(keepReasonsFor: trackIds);

  void restoreFrom(Map<String, dynamic> raw, List<Track> queue) {
    final restored = SongRadio.fromJson(
      raw,
      similar: LastFmService.getSimilarTracks,
      artistRadio: DeezerApiService().getArtistRadio,
      search: _searchCatalog,
      useLastFm: LastFmService.isConfigured,
    );
    if (restored != null) {
      restored.markQueued(queue);
      radio = restored;
      _modePref = restored.mode;
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
    final newRadio = radioFactory(seed, _modePref);
    _topUpFuture = null;
    _status = RadioStatus.loading;

    if (currentTrack?.id == seed.id) {
      radio = newRadio;
      clearQueue();
      _onStateChanged();
    } else {
      final playing = playTrack(seed, newQueue: [seed]);
      radio = newRadio;
      unawaited(playing);
    }

    final added = await topUp(force: true, count: 10);
    if (!added && identical(radio, newRadio)) {
      radio = null;
      unawaited(_persistPlaybackState());
      _onStateChanged();
    }
    return added;
  }

  /// Keeps the music going past the end of what's playing: a radio seeded
  /// with [seed] that adds similar songs after the current list, which
  /// stays as it is. Returns whether any were added.
  Future<bool> continueFrom(Track seed) async {
    if (radio != null) return topUp(force: true);
    await _loadModePref();
    if (radio != null) return topUp(force: true);
    final r = radioFactory(seed, _modePref)..markQueued(_q.tracks);
    radio = r;
    _topUpFuture = null;
    final added = await topUp(force: true, count: 10);
    if (!added && identical(radio, r)) {
      radio = null;
      unawaited(_persistPlaybackState());
      _onStateChanged();
    }
    return added;
  }

  void stop() {
    if (radio == null) return;
    radio = null;
    unawaited(_persistPlaybackState());
    _onStateChanged();
  }

  Future<void> setMode(RadioMode m) async {
    _modePref = m;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setInt(_modeKey, m.index))
        .catchError((_) => false));
    final r = radio;
    if (r == null || r.mode == m) {
      _onStateChanged();
      return;
    }
    r.setMode(m);
    unawaited(_persistPlaybackState());
    await replaceUpcoming(keep: 1);
  }

  Future<void> moreLikeThis(Track track) async {
    final r = radio;
    if (r == null) return;
    r.moreLikeThis(track);
    await replaceUpcoming(keep: 1);
  }

  Future<void> lessLikeThis(
    Track track, {
    required Future<void> Function() next,
  }) async {
    final r = radio;
    if (r == null) return;
    r.lessLikeThis(track);
    if (!_q.isShuffle) {
      for (var i = _q.length - 1; i > _q.currentIndex; i--) {
        if (r.isBanned(_q.tracks[i])) _q.removeAt(i);
      }
    }
    await topUp(force: true);
    await next();
  }

  void registerLeaving(Track incoming, Track? current, Duration position,
      Duration duration, {bool completed = false}) {
    final r = radio;
    if (r == null || current == null || current.id == incoming.id) return;
    final total = duration.inMilliseconds;
    final fraction = completed
        ? 1.0
        : (total > 0 ? (position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0);
    r.registerPlayed(current, fraction);
  }

  int _remaining() {
    if (_q.isShuffle) {
      final heard = {..._q.history, _q.currentIndex};
      return _q.length - heard.length;
    }
    return _q.length - _q.currentIndex - 1;
  }

  Future<bool> topUp({bool force = false, int count = 8}) {
    if (radio == null) return Future.value(false);
    if (!force && _remaining() >= _lowWater) return Future.value(true);
    return _topUpFuture ??=
        _doTopUp(count).whenComplete(() => _topUpFuture = null);
  }

  Future<bool> _doTopUp(int count) async {
    final r = radio;
    if (r == null) return false;
    _status = RadioStatus.loading;
    _onStateChanged();

    List<Track> batch;
    try {
      batch = await r.nextBatch(count: count);
    } catch (e) {
      _log.severe('refill failed: $e');
      batch = const [];
    }
    if (!identical(radio, r)) return false;

    final added = _q.append(batch);
    _trimHistory();
    _status = added > 0
        ? RadioStatus.ready
        : (_isOnline() ? RadioStatus.exhausted : RadioStatus.offline);
    if (added > 0) {
      unawaited(_persistPlaybackState());
    }
    _onStateChanged();
    if (added > 0) _onQueueGrew?.call();
    return added > 0;
  }

  void _trimHistory() {
    if (_q.isShuffle || _q.length <= _maxQueue) return;
    final drop = _q.currentIndex - 30;
    if (drop > 0) _q.dropBefore(drop);
  }

  Future<void> replaceUpcoming({required int keep}) async {
    final r = radio;
    if (r == null) return;
    if (!_q.isShuffle) {
      final firstReplaceable = _q.currentIndex + 1 + keep;
      for (var i = _q.length - 1; i >= firstReplaceable; i--) {
        final reason = r.reasonFor(_q.tracks[i].id);
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
