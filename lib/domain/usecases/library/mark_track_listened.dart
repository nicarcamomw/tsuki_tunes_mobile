import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/product_events.dart';

/// Marks a song as listened, unless it already is (the player calls this
/// every time a song passes the listened threshold). The song that
/// completes an album also counts as finishing it (album_completed).
@injectable
class MarkTrackListened {
  const MarkTrackListened(this._library, {ProductEvents? events}) : _events = events;

  final LibraryRepository _library;
  final ProductEvents? _events;

  Future<void> call(Track track) async {
    if (_library.isTrackListened(track.id)) return;
    await _library.markTrack(track);
    _events?.log('track_listened');
    if (track.albumId.isNotEmpty && _library.isAlbumCompleted(track.albumId)) {
      _events?.log('album_completed', {'album_id': track.albumId});
    }
  }
}
