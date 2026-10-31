import 'package:injectable/injectable.dart';

import '../../entities/album.dart';
import '../../repositories/catalog_repository.dart';

/// Looks up an album by id (a link, or a page opened with only its id).
/// Null when it doesn't exist or the catalog can't be reached.
@injectable
class GetAlbum {
  const GetAlbum(this._catalog);

  final CatalogRepository _catalog;

  Future<Album?> call(String id) async {
    if (id.isEmpty) return null;
    try {
      return await _catalog.getAlbum(id);
    } catch (_) {
      return null;
    }
  }
}
