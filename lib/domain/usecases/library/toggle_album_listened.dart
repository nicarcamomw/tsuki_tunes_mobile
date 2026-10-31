import 'package:injectable/injectable.dart';

import '../../entities/album.dart';
import '../../repositories/library_repository.dart';
import 'mark_album.dart';
import 'unmark_album.dart';

/// The album's "mark all" button: unmarks the album when every loaded song
/// is listened, otherwise marks the rest. Returns whether it is all
/// listened now.
@injectable
class ToggleAlbumListened {
  ToggleAlbumListened(LibraryRepository library)
      : _library = library,
        _mark = MarkAlbum(library),
        _unmark = UnmarkAlbum(library);

  final LibraryRepository _library;
  final MarkAlbum _mark;
  final UnmarkAlbum _unmark;

  /// Whether every loaded song of [album] is listened.
  bool isAllListened(Album album) =>
      album.tracks.isNotEmpty && album.tracks.every((t) => _library.isTrackListened(t.id));

  Future<bool> call(Album album) async {
    if (isAllListened(album)) {
      await _unmark(album);
      return false;
    }
    await _mark(album);
    return true;
  }
}
