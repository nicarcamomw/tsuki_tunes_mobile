import 'dart:math';


import '../../domain/entities/track.dart';
import 'bpm_flow.dart';
import '../../core/logger.dart';


final _log = Log.named('RainMix');

/// Builds a queue for a rainy moment out of the listener's own music: their
/// calm songs (by tempo), topped up with calm songs by their artists when
/// there aren't enough. Never a generic "rain playlist".
class RainMix {
  /// Calm tempo range. Many ballads are logged at double tempo by
  /// analysers, so those can't be told apart and are simply left out.
  static const double minBpm = 55, maxBpm = 100;
  static const int target = 24;
  /// Below this many own calm songs, the listener's artists fill in.
  static const int topUpBelow = 12;

  static bool isCalm(double? bpm) => bpm != null && bpm >= minBpm && bpm <= maxBpm;

  static Future<List<Track>> build({
    required List<Track> library,
    required List<String> artistNames,
    required BpmService bpm,
    required Future<List<Track>> Function(String query) search,
    Random? random,
    void Function(int done, int total)? onProgress,
  }) async {
    final rng = random ?? Random();
    final own = <String, Track>{};
    for (final t in library) {
      if (t.id.isNotEmpty) own.putIfAbsent(t.id, () => t);
    }
    final pool = own.values.take(120).toList();
    final tempos = await bpm.lookup(pool, concurrency: 3, onProgress: onProgress);

    final calm = pool.where((t) => isCalm(tempos[t.id])).toList()..shuffle(rng);
    final picked = calm.take(target).toList();

    if (picked.length < topUpBelow) {
      // Calm songs by the listener's own artists (Deezer filters by tempo).
      final artists = {...artistNames.where((n) => n.isNotEmpty)}.take(5);
      final filter = 'bpm_min:"${minBpm.round()}" bpm_max:"${maxBpm.round()}"';
      final seen = {...own.keys};
      final extra = <Track>[];
      for (final a in artists) {
        try {
          final found = await search('artist:"${a.replaceAll('"', '')}" $filter');
          for (final t in found.take(6)) {
            if (t.id.isNotEmpty && seen.add(t.id)) extra.add(t);
          }
        } catch (e) {
          _log.severe('search failed for $a: $e');
        }
      }
      extra.shuffle(rng);
      picked.addAll(extra.take(target - picked.length));
    }

    return windDown(picked, tempos);
  }

  /// Known tempos go from a little livelier to the calmest; songs without a
  /// known tempo keep their places. Raw tempos on purpose: the half/double
  /// folding of [BpmFlow] would rank a 60 BPM ballad as 120.
  static List<Track> windDown(List<Track> tracks, Map<String, double> tempos) {
    final slots = <int>[];
    final known = <Track>[];
    for (var i = 0; i < tracks.length; i++) {
      if (tempos[tracks[i].id] != null) {
        slots.add(i);
        known.add(tracks[i]);
      }
    }
    known.sort((a, b) => tempos[b.id]!.compareTo(tempos[a.id]!));
    final out = [...tracks];
    for (var i = 0; i < slots.length; i++) {
      out[slots[i]] = known[i];
    }
    return out;
  }

  /// Most frequent artists in [tracks] after the explicit [favorites].
  static List<String> artistsFrom(List<Track> tracks, List<String> favorites) {
    final counts = <String, int>{};
    for (final t in tracks) {
      if (t.artistName.isNotEmpty) counts[t.artistName] = (counts[t.artistName] ?? 0) + 1;
    }
    final byCount = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return {...favorites.where((n) => n.isNotEmpty), ...byCount}.toList();
  }
}
