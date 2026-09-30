import '../../models/track.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../models/artist_albums_page.dart';

abstract class MusicApiContract {
  Future<List<Artist>> searchArtists(String query, {int limit = 25});
  Future<List<Album>> searchAlbums(String query, {int limit = 10});
  Future<List<Track>> searchTracks(String query, {int limit = 25});
  Future<List<Track>> getChartTracks();
  Future<List<Artist>> getChartArtists();
  Future<List<Artist>> getFeaturedArtists();
  Future<List<Artist>> getArtists(List<String> ids);
  Future<Artist?> getArtist(String id);
  Future<List<Track>> getArtistTopTracks(String artistId, {int limit = 10});
  Future<List<Album>> getArtistAlbums(String artistId, {int limit = 25, int index = 0});
  Future<ArtistAlbumsPage> getArtistAlbumsPage(String artistId, {int limit = 50, int index = 0});
  Future<Album?> getAlbum(String albumId);
  Future<Track?> getTrack(String trackId);
  Future<List<Track>> enrichTracksWithContributors(List<Track> tracks);
  void clearCache();
}
