import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/catalog_repository.dart';

/// Looks up a song by id (a link, or a page opened with only its id).
/// Null when it doesn't exist or the catalog can't be reached.
@injectable
class GetTrack {
  const GetTrack(this._catalog);

  final CatalogRepository _catalog;

  Future<Track?> call(String id) async {
    if (id.isEmpty) return null;
    try {
      return await _catalog.getTrack(id);
    } catch (_) {
      return null;
    }
  }
}
