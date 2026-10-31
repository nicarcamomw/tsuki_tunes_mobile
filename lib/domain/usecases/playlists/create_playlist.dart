import '../../entities/playlist.dart';
import '../../entities/track.dart';
import '../../repositories/playlist_repository.dart';

/// Creates a playlist, optionally with songs already in it (saving the
/// queue or a mix). The name is trimmed; a blank one creates nothing.
/// Songs go in with the playlist in a single write: adding them right
/// after would hit the database's one-write-per-second limit.
class CreatePlaylist {
  const CreatePlaylist(this._playlists);

  final PlaylistRepository _playlists;

  Future<Playlist?> call(String name, {List<Track> tracks = const []}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return _playlists.createPlaylist(trimmed, tracks: tracks);
  }
}
