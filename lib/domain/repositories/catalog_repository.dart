import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/track.dart';

/// The music catalog (Deezer): albums, artists and songs by id. Each is
/// null when it doesn't exist or can't be reached.
abstract interface class CatalogRepository {
  Future<Album?> getAlbum(String albumId);
  Future<Artist?> getArtist(String id);
  Future<Track?> getTrack(String trackId);
}
