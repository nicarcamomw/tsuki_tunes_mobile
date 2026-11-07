import '../../entities/album.dart';
import '../../entities/artist.dart';
import '../../entities/track.dart';
import '../../logic/artist_features.dart';
import '../../repositories/music_catalog.dart';

/// What an artist's page shows, loaded at once.
class ArtistPage {
  /// Their own most played songs.
  final List<Track> topTracks;

  /// Popular songs where they only feature.
  final List<Track> features;

  /// Their releases, then the compilations they're on (each once).
  final List<Album> albums;
  final int totalAlbums;
  final bool hasMoreAlbums;
  final List<String> tags;
  final List<Artist> related;

  const ArtistPage({
    required this.topTracks,
    required this.features,
    required this.albums,
    required this.totalAlbums,
    required this.hasMoreAlbums,
    required this.tags,
    required this.related,
  });
}

typedef ArtistTagsFetcher = Future<List<String>> Function(String artistName);

/// Loads an artist's page: songs (their own and features apart), releases
/// and compilations, style tags and similar artists. Throws when the
/// catalog can't be reached, so the page can offer a retry.
class GetArtistPage {
  const GetArtistPage(this._catalog, {required ArtistTagsFetcher tags})
      : _tags = tags;

  final MusicCatalog _catalog;
  final ArtistTagsFetcher _tags;

  /// Tags are a nice extra: a failure leaves the page without them.
  Future<List<String>> _tagsOrNone(String name) async {
    try {
      return await _tags(name);
    } catch (_) {
      return const [];
    }
  }

  Future<ArtistPage> call(Artist artist) async {
    final (top, page, tags, compilations, related) = await (
      // Deezer's top mixes the artist's own songs with their features; a
      // longer list leaves enough of both after splitting them.
      _catalog.getArtistTopTracks(artist.id, limit: 50),
      _catalog.getArtistAlbumsPage(artist.id, limit: 250, index: 0),
      _tagsOrNone(artist.name),
      _catalog.getArtistCompilations(artist.id),
      _catalog.getRelatedArtists(artist.id),
    ).wait;

    final ownIds = {for (final a in page.items) a.id};
    final extraCompilations =
        compilations.where((c) => !ownIds.contains(c.id)).toList();
    final split =
        ArtistFeatures.split(top, artistId: artist.id, artistName: artist.name);
    return ArtistPage(
      topTracks: split.own.take(10).toList(),
      features: split.features.take(20).toList(),
      albums: [...page.items, ...extraCompilations],
      totalAlbums: page.total + extraCompilations.length,
      hasMoreAlbums: page.hasMore,
      tags: tags,
      related: related,
    );
  }
}
