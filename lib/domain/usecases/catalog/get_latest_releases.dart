import '../../entities/album.dart';
import '../../entities/artist.dart';
import '../../repositories/music_catalog.dart';

/// The newest releases of some artists (the user's favourites, or featured
/// ones): from the last year, newest first, each once. An artist whose
/// releases can't be loaded is skipped.
class GetLatestReleases {
  const GetLatestReleases(this._catalog, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final MusicCatalog _catalog;
  final DateTime Function() _now;

  static const Duration window = Duration(days: 365);

  Future<List<Album>> call(List<Artist> artists, {int limit = 15}) async {
    final cutoff = _now().subtract(window);
    final perArtist = await Future.wait(artists.map((artist) async {
      try {
        final albums = await _catalog.getArtistAlbums(artist.id);
        // Deezer's artist/albums listing leaves the artist out of each one.
        return [
          for (final a in albums)
            a.copyWith(
              artistName: (a.artistName.isEmpty || a.artistName == 'Unknown Artist')
                  ? artist.name
                  : a.artistName,
              artistId: a.artistId.isEmpty ? artist.id : a.artistId,
            ),
        ];
      } catch (_) {
        return const <Album>[];
      }
    }));

    final seen = <String>{};
    final recent = <Album>[];
    for (final albums in perArtist) {
      for (final album in albums) {
        final released = DateTime.tryParse(album.releaseDate);
        if (released == null || !released.isAfter(cutoff)) continue;
        if (seen.add(album.id)) recent.add(album);
      }
    }
    recent.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    return recent.take(limit).toList();
  }
}
