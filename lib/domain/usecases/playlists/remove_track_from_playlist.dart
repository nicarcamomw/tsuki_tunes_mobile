import '../../entities/track.dart';
import '../../repositories/playlist_repository.dart';

/// Takes a song out of a playlist. Returns the undo, which puts it back in
/// the same place.
class RemoveTrackFromPlaylist {
  const RemoveTrackFromPlaylist(this._playlists);

  final PlaylistRepository _playlists;

  Future<void> Function() call(String playlistId, Track track, int index) {
    _playlists.removeTrackFromPlaylist(playlistId, track.id);
    return () => _playlists.insertTrackAt(playlistId, track, index);
  }
}
