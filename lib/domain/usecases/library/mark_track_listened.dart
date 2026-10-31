import '../../entities/track.dart';
import '../../repositories/library_repository.dart';

/// Marks a song as listened, unless it already is (the player calls this
/// every time a song passes the listened threshold).
class MarkTrackListened {
  const MarkTrackListened(this._library);

  final LibraryRepository _library;

  Future<void> call(Track track) async {
    if (_library.isTrackListened(track.id)) return;
    await _library.markTrack(track);
  }
}
