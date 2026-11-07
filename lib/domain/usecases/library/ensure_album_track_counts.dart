import '../../entities/album.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/library_repository.dart';

/// Makes sure the library knows how many songs the albums on screen have,
/// so it can tell which are complete; the counts come from the catalog.
/// Cheap enough to call from build.
class EnsureAlbumTrackCounts {
  const EnsureAlbumTrackCounts(this._library, this._catalog);

  final LibraryRepository _library;
  final CatalogRepository _catalog;

  void call(Iterable<Album> albums) =>
      _library.ensureAlbumTrackCounts(albums, _catalog.getAlbum);

  /// The latest listened albums, wherever the user is.
  void recent() => _library.ensureRecentAlbumTrackCounts(_catalog.getAlbum);
}
