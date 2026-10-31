import '../../repositories/playlist_repository.dart';

/// Renames a playlist; a blank name leaves it as it was.
class RenamePlaylist {
  const RenamePlaylist(this._playlists);

  final PlaylistRepository _playlists;

  Future<void> call(String playlistId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _playlists.renamePlaylist(playlistId, trimmed);
  }
}
