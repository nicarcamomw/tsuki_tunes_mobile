import 'dart:math';

import '../entities/track.dart';

/// Songs that stand for a whole list, for smart shuffle's recommendations
/// to grow from: one song of each of its most present artists, the most
/// present first. Seeded by the song playing alone, a list that mixes
/// styles got recommendations jumping from one style to the next.
List<Track> listSeeds(List<Track> tracks, {int max = 6, Random? random}) {
  final rng = random ?? Random();
  final byArtist = <String, List<Track>>{};
  for (final t in tracks) {
    final key = t.artistId.isNotEmpty ? t.artistId : t.artistName.toLowerCase().trim();
    if (key.isEmpty) continue;
    (byArtist[key] ??= []).add(t);
  }
  final groups = byArtist.values.toList()
    // Most songs first; ties in the list's order (a stable sort).
    ..sort((a, b) => b.length.compareTo(a.length));
  return [
    for (final g in groups.take(max)) g[rng.nextInt(g.length)],
  ];
}

/// Recommended songs already played lately (id → when), so the same one
/// doesn't come back tomorrow if it wasn't kept.
class RecentRecommendations {
  RecentRecommendations([Map<String, DateTime>? seen]) : _seen = {...?seen};

  /// How long a played recommendation stays out.
  static const window = Duration(days: 14);

  /// The most remembered (the oldest go first past it).
  static const capacity = 800;

  final Map<String, DateTime> _seen;

  Map<String, DateTime> get seen => Map.unmodifiable(_seen);

  bool isRecent(String id, DateTime now) {
    final at = _seen[id];
    return at != null && now.difference(at) < window;
  }

  void record(String id, DateTime now) {
    _seen.remove(id);
    _seen[id] = now; // newest last
    prune(now);
  }

  void prune(DateTime now) {
    _seen.removeWhere((_, at) => now.difference(at) >= window);
    while (_seen.length > capacity) {
      _seen.remove(_seen.keys.first);
    }
  }

  Map<String, int> toJson() => {for (final e in _seen.entries) e.key: e.value.millisecondsSinceEpoch ~/ 1000};

  static RecentRecommendations fromJson(Object? raw) => RecentRecommendations(raw is Map
      ? {
          for (final e in raw.entries)
            if (e.value is num)
              e.key.toString(): DateTime.fromMillisecondsSinceEpoch((e.value as num).toInt() * 1000),
        }
      : null);
}
