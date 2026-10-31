import 'package:injectable/injectable.dart';

import '../../entities/artist.dart';
import '../../repositories/catalog_repository.dart';

/// Looks up an artist by id (a link, or a page opened with only its id).
/// Null when it doesn't exist or the catalog can't be reached.
@injectable
class GetArtist {
  const GetArtist(this._catalog);

  final CatalogRepository _catalog;

  Future<Artist?> call(String id) async {
    if (id.isEmpty) return null;
    try {
      return await _catalog.getArtist(id);
    } catch (_) {
      return null;
    }
  }
}
