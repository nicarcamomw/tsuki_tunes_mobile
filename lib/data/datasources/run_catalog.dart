import 'dart:async';
import 'dart:math';

import '../../core/logger.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/pace_matcher.dart';
import 'bpm_flow.dart';


final _log = Log.named('RunCatalog');

/// Finds songs at a given pace: the listener's own songs whose tempo is
/// known, plus Deezer searches filtered by tempo (Deezer's advanced search
/// accepts `bpm_min` / `bpm_max`), seeded with their favourite artists.
class RunCatalog {
  final BpmService bpm;
  final Future<List<Track>> Function(String query) search;

  RunCatalog({required this.bpm, required this.search});

  /// Every track seen so far, by id.
  final Map<String, Track> _tracks = {};
  /// Exact tempos, from the tempo service.
  final Map<String, double> _bpms = {};
  /// Tempo ranges already searched.
  final List<(int, int)> _searched = [];
  final Set<String> favoriteIds = {};
  List<String> _seedArtists = const [];
  Future<void>? _warming;

  int get knownCount => _bpms.length;
  Map<String, double> get bpms => _bpms;
  Iterable<Track> get tracks => _tracks.values;

  /// Registers the listener's library. Tempos of up to [limit] songs are
  /// looked up in the background (each costs one request, once ever).
  Future<void> warmUp({
    required List<Track> favorites,
    required List<Track> recent,
    required List<String> favoriteArtistNames,
    int limit = 150,
  }) {
    favoriteIds
      ..clear()
      ..addAll(favorites.map((t) => t.id));
    final own = <String, Track>{};
    for (final t in [...favorites, ...recent]) {
      if (t.id.isNotEmpty) own.putIfAbsent(t.id, () => t);
    }
    // Most played artists of the library after the explicit favourites.
    final counts = <String, int>{};
    for (final t in own.values) {
      if (t.artistName.isNotEmpty) counts[t.artistName] = (counts[t.artistName] ?? 0) + 1;
    }
    final byCount = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    _seedArtists = {...favoriteArtistNames.where((n) => n.isNotEmpty), ...byCount}.take(6).toList();

    final list = own.values.take(limit).toList();
    for (final t in list) {
      _tracks[t.id] = t;
      final known = bpm.cached(t.id);
      if (known != null) _bpms[t.id] = known;
    }
    return _warming ??= bpm.lookup(list, concurrency: 2).then((found) {
      _bpms.addAll(found);
    }).catchError((Object e) {
      _log.severe('warm-up failed: $e');
    });
  }

  /// Searches Deezer for songs around [cadence] (each tempo band once per
  /// session). Returns how many new tracks were found.
  Future<int> explore(double cadence) async {
    var added = 0;
    for (final tempo in PaceMatcher.targetTempos(cadence)) {
      final lo = (tempo * (1 - PaceMatcher.tolerance)).floor();
      final hi = (tempo * (1 + PaceMatcher.tolerance)).ceil();
      // A range mostly covered by an earlier search reuses its results, so
      // small cadence changes don't search again.
      final margin = (hi - lo) * 0.25;
      if (_searched.any((r) => r.$1 <= lo + margin && r.$2 >= hi - margin)) continue;
      _searched.add((lo, hi));
      final filter = 'bpm_min:"$lo" bpm_max:"$hi"';
      final queries = [
        for (final a in _seedArtists) 'artist:"${a.replaceAll('"', '')}" $filter',
        filter,
      ];
      final results = await Future.wait(queries.map((q) => search(q).catchError((Object e) {
            _log.severe('search failed ($q): $e');
            return <Track>[];
          })));
      for (final list in results) {
        for (final t in list) {
          if (t.id.isEmpty || _tracks.containsKey(t.id)) continue;
          _tracks[t.id] = t;
          added++;
        }
      }
    }
    return added;
  }

  /// Tempo of [track], asking Deezer if it is not known yet.
  Future<double?> tempoOf(Track track) async {
    final known = _bpms[track.id] ?? bpm.cached(track.id);
    if (known != null) return _bpms[track.id] = known;
    final found = await bpm.lookup([track]);
    final v = found[track.id];
    if (v != null) _bpms[track.id] = v;
    return v;
  }

  /// Picks the next song for [cadence]. Search results whose exact tempo is
  /// still unknown are checked one at a time (their band is only a range),
  /// so what gets queued has a verified tempo.
  Future<Track?> next(
    double cadence, {
    Set<String> avoid = const {},
    String? lastArtistId,
    Random? random,
  }) async {
    final rng = random ?? Random();
    final known = PaceMatcher.pick(_tracks.values, _bpms, cadence,
        avoid: avoid, lastArtistId: lastArtistId, favorites: favoriteIds, random: rng);
    if (known != null) return known;

    // Unverified search results, shuffled so sessions differ.
    final pending = _tracks.values
        .where((t) => !avoid.contains(t.id) && !_bpms.containsKey(t.id) && bpm.cached(t.id) == null)
        .toList()
      ..shuffle(rng);
    for (final t in pending.take(8)) {
      final tempo = await tempoOf(t);
      if (tempo == null) continue;
      if (PaceMatcher.match(tempo, cadence).deviation <= PaceMatcher.tolerance) return t;
    }
    return null;
  }
}
