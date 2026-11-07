import '../../entities/artist.dart';
import '../../repositories/music_catalog.dart';

/// Artists similar to a few seed artists, the seeds' own first, each once
/// and none of [exclude] (the seeds and anyone already shown).
class GetSimilarArtists {
  const GetSimilarArtists(this._catalog);

  final MusicCatalog _catalog;

  Future<List<Artist>> call(
    List<Artist> seeds, {
    Set<String> exclude = const {},
    int perSeed = 10,
    int limit = 15,
  }) async {
    final seen = {...exclude, for (final s in seeds) s.id};
    final out = <Artist>[];
    for (final seed in seeds) {
      if (out.length >= limit) break;
      final related = await _catalog.getRelatedArtists(seed.id, limit: perSeed);
      for (final a in related) {
        if (a.id.isNotEmpty && seen.add(a.id)) out.add(a);
      }
    }
    return out.take(limit).toList();
  }
}
