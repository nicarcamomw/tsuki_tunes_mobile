import 'package:injectable/injectable.dart';

import '../../repositories/playlist_repository.dart';

/// Moves a song inside a playlist (edit mode's drag handle).
@injectable
class ReorderPlaylist {
  const ReorderPlaylist(this._playlists);

  final PlaylistRepository _playlists;

  Future<void> call(String playlistId, int oldIndex, int newIndex) =>
      _playlists.reorderTrack(playlistId, oldIndex, newIndex);
}
