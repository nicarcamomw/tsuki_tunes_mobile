import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/track.dart';

/// The user's library: songs marked as listened (and so the albums they
/// complete), favourite songs and artists, followed artists and history.
///
/// Writes need a signed-in account and do nothing for guests.
abstract interface class LibraryRepository {
  bool isTrackListened(String trackId);
  Future<void> markTrack(Track track);
  Future<void> unmarkTrack(String trackId);

  /// Marks [tracks] at once; [albumId] and [totalTracks] record how many
  /// songs the album has, so it can count as completed.
  Future<void> markAlbumTracks(List<Track> tracks, {String? albumId, int? totalTracks});
  Future<void> unmarkAlbumTracks(List<String> trackIds);
  void registerAlbumTrackCount(String albumId, int count);
  int getAlbumTracksCount(String albumId);
  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0});

  /// Asks [fetchAlbum] for the song count of the [albums] with listened
  /// songs and no known count, once per album per session, so they can be
  /// judged complete. Cheap enough to call from build.
  void ensureAlbumTrackCounts(Iterable<Album> albums,
      Future<Album?> Function(String albumId) fetchAlbum);

  /// The same for the most recently listened albums, wherever they are.
  void ensureRecentAlbumTrackCounts(
      Future<Album?> Function(String albumId) fetchAlbum);

  bool isFavoriteTrack(String trackId);
  Future<void> toggleFavoriteTrack(Track track);
  bool isFavoriteArtist(String artistId);
  Future<void> toggleFavoriteArtist(Artist artist);

  bool isArtistFollowed(String artistId);
  Future<void> followArtist(Artist artist);
  Future<void> unfollowArtist(String artistId);

  Future<void> addRecentTrack(Track track);

  /// Counts a play for the stats, Wrapped and the listening clock.
  Future<void> recordPlay(Track track);
}
