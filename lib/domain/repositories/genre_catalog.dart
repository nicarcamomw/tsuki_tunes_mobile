import '../entities/artist.dart';
import '../entities/genre.dart';
import '../entities/track.dart';

/// Music genres to explore (Deezer): the list, and each one's artists and
/// most played songs.
abstract interface class GenreCatalog {
  /// Empty when the genres can't be reached.
  Future<List<Genre>> getGenres();

  /// Throw when the catalog can't be reached.
  Future<List<Artist>> getGenreArtists(String genreId);
  Future<List<Track>> getGenreChartTracks(String genreId);
}
