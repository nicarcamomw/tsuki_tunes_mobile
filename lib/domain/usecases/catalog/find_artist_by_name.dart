import '../../entities/artist.dart';
import '../../repositories/music_catalog.dart';

/// The catalog artist for a name the library knows (it keeps names, not
/// ids): the one named exactly so, else the best match. Null when there is
/// none or the catalog can't be reached.
class FindArtistByName {
  const FindArtistByName(this._catalog);

  final MusicCatalog _catalog;

  Future<Artist?> call(String name) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    try {
      final results = await _catalog.searchArtists(name.trim(), limit: 3);
      for (final a in results) {
        if (a.name.toLowerCase() == wanted) return a;
      }
      return results.isNotEmpty ? results.first : null;
    } catch (_) {
      return null;
    }
  }
}
