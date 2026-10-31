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
  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0});

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
