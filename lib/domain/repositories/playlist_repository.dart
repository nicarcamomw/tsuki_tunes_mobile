import '../entities/playlist.dart';
import '../entities/track.dart';

/// The user's playlists. Writes need a signed-in (or local guest) account.
abstract interface class PlaylistRepository {
  List<Playlist> get playlists;

  /// Null when it couldn't be created (empty name, no account).
  Future<Playlist?> createPlaylist(String name, {List<Track> tracks = const []});
  Future<void> renamePlaylist(String playlistId, String newName);
  Future<void> deletePlaylist(String playlistId);

  /// False when the song was already there or the write was refused.
  Future<bool> addTrackToPlaylist(String playlistId, Track track);
  Future<bool> insertTrackAt(String playlistId, Track track, int index);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex);
}
