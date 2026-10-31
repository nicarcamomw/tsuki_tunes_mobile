import 'package:injectable/injectable.dart';

import '../../entities/album.dart';
import '../../repositories/library_repository.dart';

/// Takes every song of an album off the listened list.
@injectable
class UnmarkAlbum {
  const UnmarkAlbum(this._library);

  final LibraryRepository _library;

  Future<void> call(Album album) =>
      _library.unmarkAlbumTracks(album.tracks.map((t) => t.id).toList());
}
