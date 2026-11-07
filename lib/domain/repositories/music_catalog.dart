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

  /// A song by id; [forceRefresh] skips the cache (a fresh preview URL).
  @override
  Future<Track?> getTrack(String trackId, {bool forceRefresh = false});

  /// The song with this ISRC (the recording's code), or null.
  Future<Track?> findTrackByIsrc(String isrc);

  /// The worldwide top songs, a long list (games, mixes).
  Future<List<Track>> getLargeChartTracks();

  /// Song search that keeps little-known songs, for looking up one in
  /// particular. Throws when the catalog can't be reached.
  Future<List<Track>> searchTracksUnfiltered(String query, {int limit = 25});

  /// Warms the cache of these artists' similar artists, one at a time.
  Future<void> prefetchRelatedArtists(Iterable<String> artistIds);
}
