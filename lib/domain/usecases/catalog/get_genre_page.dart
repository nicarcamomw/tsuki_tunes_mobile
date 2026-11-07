import '../../entities/artist.dart';
import '../../entities/track.dart';
import '../../repositories/genre_catalog.dart';

/// What a genre's page shows.
class GenrePage {
  final List<Artist> artists;
  final List<Track> tracks;
  const GenrePage(this.artists, this.tracks);

  bool get isEmpty => artists.isEmpty && tracks.isEmpty;
}

/// A genre's best known artists and most played songs, both at once.
/// Throws when the catalog can't be reached, so the page can offer a retry.
class GetGenrePage {
  const GetGenrePage(this._catalog);

  final GenreCatalog _catalog;

  Future<GenrePage> call(String genreId) async {
    final (artists, tracks) = await (
      _catalog.getGenreArtists(genreId),
      _catalog.getGenreChartTracks(genreId),
    ).wait;
    return GenrePage(artists, tracks);
  }
}
