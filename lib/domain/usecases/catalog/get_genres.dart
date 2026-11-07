import '../../entities/genre.dart';
import '../../repositories/genre_catalog.dart';

/// The genres the search screen offers to explore. Empty when they can't
/// be reached, so the section just stays hidden.
class GetGenres {
  const GetGenres(this._catalog);

  final GenreCatalog _catalog;

  Future<List<Genre>> call() async {
    try {
      return await _catalog.getGenres();
    } catch (_) {
      return const [];
    }
  }
}
