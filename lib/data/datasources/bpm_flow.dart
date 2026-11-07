import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/track.dart';
import 'deezer_api_service.dart';

export '../../domain/logic/bpm_flow.dart';


final _log = Log.named('BPM');

/// Looks up and remembers each track's tempo and loudness. Deezer only
/// returns them from the per-track endpoint, so each track costs one
/// request, once.
class BpmService {
  static final BpmService shared = BpmService();
  static const _cacheKey = 'bpm_cache_v1';
  /// Deezer allows 50 requests per 5 s; stay well under it.
  static const Duration minRequestGap = Duration(milliseconds: 130);
  /// Unknown values are asked again after this, in case Deezer adds them.
  static const Duration unknownRetryAfter = Duration(days: 30);

  final Future<TrackAudioInfo?> Function(String trackId) _fetch;
  final Duration _gap;
  final Map<String, double> _bpm = {};
  final Map<String, double> _gain = {};
  final Map<String, int> _unknownSince = {};
  final Map<String, Future<bool>> _inFlight = {};
  Future<void>? _loading;

  /// Bumps whenever a tempo or loudness is learned, so what shows them can
  /// update when they arrive instead of only showing what was cached.
  final ValueNotifier<int> revision = ValueNotifier(0);
  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  BpmService({Future<TrackAudioInfo?> Function(String trackId)? fetch, Duration? gap})
      : _fetch = fetch ?? DeezerApiService().getTrackAudioInfo,
        _gap = gap ?? minRequestGap;

  Future<void> _load() => _loading ??= _doLoad();

  Future<void> _doLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      (m['bpm'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _bpm[k] = (v as num).toDouble());
      (m['gain'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _gain[k] = (v as num).toDouble());
      (m['unknown'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _unknownSince[k] = v as int);
    } catch (e) {
      _log.severe('cache load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode({'bpm': _bpm, 'gain': _gain, 'unknown': _unknownSince}));
    } catch (_) {}
  }

  /// Fetched before (known or recently unknown) and not worth asking again.
  bool _settled(String id) {
    if (_bpm.containsKey(id) || _gain.containsKey(id)) return true;
    final since = _unknownSince[id];
    if (since == null) return false;
    return DateTime.now().millisecondsSinceEpoch - since <= unknownRetryAfter.inMilliseconds;
  }

  Future<void> _paced() async {
    final now = DateTime.now();
    final start = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = start.add(_gap);
    final wait = start.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  /// Fetches one track. Returns false when the request failed. The same
  /// track asked from two places (flow, shuffle, player) is fetched once.
  Future<bool> _fetchOne(String id) =>
      _inFlight[id] ??= _doFetchOne(id).whenComplete(() {
        _inFlight.remove(id);
      });

  Future<bool> _doFetchOne(String id) async {
    await _paced();
    final info = await _fetch(id);
    if (info == null) return false;
    if (info.bpm > 0) _bpm[id] = info.bpm;
    if (info.gain != null) _gain[id] = info.gain!;
    if (info.bpm > 0 || info.gain != null) {
      _unknownSince.remove(id);
      revision.value++;
    } else {
      _unknownSince[id] = DateTime.now().millisecondsSinceEpoch;
    }
    return true;
  }

  /// Known tempos for [tracks] (unknown ones are left out). [onProgress]
  /// reports (done, toLookUp) while missing ones are fetched.
  Future<Map<String, double>> lookup(
    List<Track> tracks, {
    void Function(int done, int total)? onProgress,
    int concurrency = 4,
  }) async {
    await _load();
    final missing = tracks.map((t) => t.id).where((id) => id.isNotEmpty).toSet()
      ..removeWhere(_settled);
    final queue = missing.toList();
    var done = 0;
    lastFailures = 0;
    onProgress?.call(0, queue.length);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        if (!await _fetchOne(id)) lastFailures++;
        done++;
        onProgress?.call(done, missing.length);
      }
    }

    if (missing.isNotEmpty) {
      await Future.wait(List.generate(min(concurrency, missing.length), (_) => worker()));
      await _save();
    }
    return {
      for (final t in tracks)
        if (_bpm[t.id] != null) t.id: _bpm[t.id]!,
    };
  }

  /// Loudness of [trackId], fetching it if this device never has.
  Future<double?> gainFor(String trackId) async {
    await _load();
    if (trackId.isEmpty) return null;
    if (!_settled(trackId) && await _fetchOne(trackId)) await _save();
    return _gain[trackId];
  }

  /// Makes sure [trackId]'s tempo and loudness were asked for (one request,
  /// remembered); [revision] bumps when they arrive.
  Future<void> ensure(String trackId) => gainFor(trackId);

  double? cached(String trackId) => _bpm[trackId];
  double? cachedGain(String trackId) => _gain[trackId];

  /// Requests that failed in the last [lookup] (network), not unknown values.
  int lastFailures = 0;
}
