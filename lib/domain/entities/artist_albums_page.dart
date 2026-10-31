import 'album.dart';

class ArtistAlbumsPage {
  final List<Album> items;
  final int total;
  final bool hasMore;
  final int nextIndex;

  const ArtistAlbumsPage({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.nextIndex,
  });

  static const empty = ArtistAlbumsPage(
    items: [],
    total: 0,
    hasMore: false,
    nextIndex: 0,
  );
}
