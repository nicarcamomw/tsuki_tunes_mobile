import 'package:injectable/injectable.dart';

import '../../repositories/playlist_repository.dart';

/// Deletes a playlist.
@injectable
class DeletePlaylist {
  const DeletePlaylist(this._playlists);

  final PlaylistRepository _playlists;

  Future<void> call(String playlistId) => _playlists.deletePlaylist(playlistId);
}
