import 'package:injectable/injectable.dart';

import '../../entities/playlist.dart';
import '../../entities/track.dart';
import '../../repositories/playlist_repository.dart';
import '../../repositories/product_events.dart';

/// Creates a playlist, optionally with songs already in it (saving the
/// queue or a mix). The name is trimmed; a blank one creates nothing.
/// Songs go in with the playlist in a single write: adding them right
/// after would hit the database's one-write-per-second limit.
@injectable
class CreatePlaylist {
  const CreatePlaylist(this._playlists, {ProductEvents? events}) : _events = events;

  final PlaylistRepository _playlists;
  final ProductEvents? _events;

  Future<Playlist?> call(String name, {List<Track> tracks = const []}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final playlist = await _playlists.createPlaylist(trimmed, tracks: tracks);
    _events?.log('playlist_created', {'tracks': tracks.length});
    return playlist;
  }
}
