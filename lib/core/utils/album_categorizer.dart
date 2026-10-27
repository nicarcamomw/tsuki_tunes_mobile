import '../../models/album.dart';

/// Pure categorization of an artist's albums into buckets.
/// Extracted from the artist detail / discography screens so it can be tested
/// without widgets.
class AlbumCategorizer {
  AlbumCategorizer._();

  static bool isOwnRelease(Album album, {required String artistId, required String artistName}) {
    if (album.artistId.isNotEmpty) return album.artistId == artistId;
    return album.artistName.toLowerCase().trim() ==
        artistName.toLowerCase().trim();
  }

  static Map<String, List<Album>> categorize(
    List<Album> albums, {
    required String artistId,
    required String artistName,
  }) {
    final Map<String, List<Album>> cats = {
      'album': [],
      'ep': [],
      'single': [],
      'appears_on': [],
    };
    for (final a in albums) {
      if (!isOwnRelease(a, artistId: artistId, artistName: artistName)) {
        cats['appears_on']!.add(a);
      } else if (a.recordType == 'album') {
        cats['album']!.add(a);
      } else if (a.recordType == 'ep' || a.recordType == 'compile') {
        cats['ep']!.add(a);
      } else if (a.recordType == 'single') {
        cats['single']!.add(a);
      } else {
        cats['album']!.add(a);
      }
    }
    return cats;
  }
}
