import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/artist_albums_page.dart';
import '../entities/track.dart';
import 'catalog_repository.dart';

/// The music catalog (Deezer) as the screens browse it: artists, their
/// releases and songs, and who sounds like whom.
abstract interface class MusicCatalog implements CatalogRepository {
  /// A curated set of artists, for users with nothing listened yet.
  Future<List<Artist>> getFeaturedArtists();

  /// Throws when the catalog can't be reached.
  Future<List<Artist>> searchArtists(String query, {int limit = 25});

  Future<List<Track>> getArtistTopTracks(String artistId, {int limit = 10});
  Future<List<Album>> getArtistAlbums(String artistId, {int limit = 250, int index = 0});
  Future<ArtistAlbumsPage> getArtistAlbumsPage(String artistId, {int limit = 50, int index = 0});
  Future<List<Album>> getArtistCompilations(String artistId, {int limit = 50});

  /// Empty on failure unless [throwOnError].
  Future<List<Artist>> getRelatedArtists(String artistId,
      {int limit = 20, bool throwOnError = false});

  /// The same songs with every artist of each collaboration.
  Future<List<Track>> enrichTracksWithContributors(List<Track> tracks);
}
