import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'deezer_api_service.dart';

enum FlowMode {
  /// Tempo climbs gradually: warm-up, workout, party.
  rise,
  /// Tempo winds down: evening, studying, sleep.
  calm,
  /// Builds to a peak about two thirds in, then cools down, like a DJ set.
  wave,
}

class FlowResult {
  final List<Track> order;
  final int known;
  final int total;
  final double? fromBpm;
  final double? peakBpm;
  final double? toBpm;

  const FlowResult({
    required this.order,
    required this.known,
    required this.total,
    this.fromBpm,
    this.peakBpm,
    this.toBpm,
  });

  double get coverage => total == 0 ? 0 : known / total;
}

/// Orders a queue by tempo.
class BpmFlow {
  /// Below this share of known tempos the result is mostly guesswork.
  static const double minUsefulCoverage = 0.4;

  /// Folds half and double time into one octave, so a 70 BPM ballad and a
  /// 140 BPM track count as the same feel, the way DJs pair them.
  static double feel(double bpm) {
    var b = bpm;
    while (b < 85) {
      b *= 2;
    }
    while (b >= 170) {
      b /= 2;
    }
    return b;
  }

  /// Reorders [tracks]. Tracks without a known tempo keep their exact
  /// positions; the others fill the remaining slots in flow order. Ties keep
  /// their original order, so runs from the same album stay together.
  static FlowResult arrange(
    List<Track> tracks,
    Map<String, double> bpms,
    FlowMode mode,
  ) {
    final knownSlots = <int>[];
    final known = <(int, Track, double)>[];
    for (var i = 0; i < tracks.length; i++) {
      final bpm = bpms[tracks[i].id];
      if (bpm != null && bpm > 0) {
        knownSlots.add(i);
        known.add((i, tracks[i], feel(bpm)));
      }
    }

    final ascending = [...known]..sort((a, b) {
        final c = a.$3.compareTo(b.$3);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });

    final List<(int, Track, double)> ordered;
    switch (mode) {
      case FlowMode.rise:
        ordered = ascending;
      case FlowMode.calm:
        ordered = ascending.reversed.toList();
      case FlowMode.wave:
        // Two of every three steps go into the climb, the rest into the
        // cool-down (played in reverse), so the peak lands ~2/3 through.
        final up = <(int, Track, double)>[];
        final down = <(int, Track, double)>[];
        for (var i = 0; i < ascending.length; i++) {
          (i % 3 == 2 ? down : up).add(ascending[i]);
        }
        ordered = [...up, ...down.reversed];
    }

    final result = [...tracks];
    for (var i = 0; i < knownSlots.length; i++) {
      result[knownSlots[i]] = ordered[i].$2;
    }

    return FlowResult(
      order: result,
      known: known.length,
      total: tracks.length,
      fromBpm: ordered.isEmpty ? null : ordered.first.$3,
      peakBpm: ordered.isEmpty ? null : ordered.map((e) => e.$3).reduce(max),
      toBpm: ordered.isEmpty ? null : ordered.last.$3,
    );
  }
}

/// Looks up and remembers track tempos. Deezer only returns BPM from the
/// per-track endpoint, so each track costs one request, once.
class BpmService {
  static final BpmService shared = BpmService();
  static const _cacheKey = 'bpm_cache_v1';
  /// Deezer allows 50 requests per 5 s; stay well under it.
  static const Duration minRequestGap = Duration(milliseconds: 130);
  /// Unknown tempos are asked again after this, in case Deezer adds them.
  static const Duration unknownRetryAfter = Duration(days: 30);

  final Future<double?> Function(String trackId) _fetch;
  final Duration _gap;
  final Map<String, double> _bpm = {};
  final Map<String, int> _unknownSince = {};
  bool _loaded = false;
  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  BpmService({Future<double?> Function(String trackId)? fetch, Duration? gap})
      : _fetch = fetch ?? DeezerApiService().getTrackBpm,
        _gap = gap ?? minRequestGap;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      (m['bpm'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _bpm[k] = (v as num).toDouble());
      (m['unknown'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _unknownSince[k] = v as int);
    } catch (e) {
      debugPrint('[BPM] cache load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({'bpm': _bpm, 'unknown': _unknownSince}));
    } catch (_) {}
  }

  bool _needsLookup(String id) {
    if (_bpm.containsKey(id)) return false;
    final since = _unknownSince[id];
    if (since == null) return true;
    return DateTime.now().millisecondsSinceEpoch - since > unknownRetryAfter.inMilliseconds;
  }

  Future<void> _paced() async {
    final now = DateTime.now();
    final start = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = start.add(_gap);
    final wait = start.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
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
      ..removeWhere((id) => !_needsLookup(id));
    final queue = missing.toList();
    var done = 0;
    lastFailures = 0;
    onProgress?.call(0, queue.length);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        await _paced();
        final bpm = await _fetch(id);
        if (bpm == null) lastFailures++;
        if (bpm != null) {
          if (bpm > 0) {
            _bpm[id] = bpm;
            _unknownSince.remove(id);
          } else {
            _unknownSince[id] = DateTime.now().millisecondsSinceEpoch;
          }
        }
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

  double? cached(String trackId) => _bpm[trackId];

  /// Requests that failed in the last [lookup] (network), not unknown tempos.
  int lastFailures = 0;
}
