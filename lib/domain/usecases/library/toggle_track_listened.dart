import '../../entities/track.dart';
import '../../repositories/library_repository.dart';

/// The listened mark on a song row, mini player or player: marks it, or
/// unmarks it if it was marked. Returns whether it is listened now.
class ToggleTrackListened {
  const ToggleTrackListened(this._library);

  final LibraryRepository _library;

  Future<bool> call(Track track) async {
    if (_library.isTrackListened(track.id)) {
      await _library.unmarkTrack(track.id);
      return false;
    }
    await _library.markTrack(track);
    return true;
  }
}
