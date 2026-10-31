import 'package:injectable/injectable.dart';

import '../../entities/playlist.dart';
import '../../entities/track.dart';
import '../../repositories/playlist_repository.dart';

enum AddToPlaylistResult {
  added,

  /// The song was in the playlist already; nothing changed.
  alreadyThere,

  /// The playlist has [Playlist.maxTracks] songs.
  full,

  /// The write was refused (signed out, too many writes at once).
  failed,
}

/// Adds a song to the end of a playlist.
@injectable
class AddTrackToPlaylist {
  const AddTrackToPlaylist(this._playlists);

  final PlaylistRepository _playlists;

  /// What adding would do, without writing: screens answer at once and
  /// let the write finish in the background.
  AddToPlaylistResult check(Playlist playlist, Track track) {
    if (playlist.contains(track.id)) return AddToPlaylistResult.alreadyThere;
    if (playlist.isFull) return AddToPlaylistResult.full;
    return AddToPlaylistResult.added;
  }

  Future<AddToPlaylistResult> call(Playlist playlist, Track track) async {
    final expected = check(playlist, track);
    if (expected != AddToPlaylistResult.added) return expected;
    final ok = await _playlists.addTrackToPlaylist(playlist.id, track);
    return ok ? AddToPlaylistResult.added : AddToPlaylistResult.failed;
  }
}
