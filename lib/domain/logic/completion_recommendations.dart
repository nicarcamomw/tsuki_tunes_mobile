import '../entities/album_progress.dart';
import '../entities/artist.dart';

/// Artists similar to the one behind an album the user completed.
class CompletionRecommendation {
  /// The completed album that gave the suggestions.
  final AlbumProgress album;
  final List<Artist> artists;
  const CompletionRecommendation(this.album, this.artists);
}

typedef ArtistFinder = Future<Artist?> Function(String name);
typedef RelatedArtistsFetcher = Future<List<Artist>> Function(String artistId);

/// "Because you completed X": takes the artists of the most recently
/// completed albums and suggests artists similar to them that the user has
/// not listened to yet.
///
/// Pure logic: finding an artist by name and their related artists are
/// passed in, so it has no network or Deezer dependency.
class CompletionRecommendations {
  CompletionRecommendations({
    required this.findArtist,
    required this.relatedArtists,
    this.maxSeeds = 2,
    this.perSeed = 10,
    this.minPerSeed = 3,
  });

  final ArtistFinder findArtist;
  final RelatedArtistsFetcher relatedArtists;

  /// Completed albums (with different artists) that get a row each.
  final int maxSeeds;

  /// Artists in each row, at most.
  final int perSeed;

  /// A row with fewer suggestions than this is dropped.
  final int minPerSeed;

  /// One row per seed album, most recent first. [completed] are the
  /// completed albums, most recent first; [knownArtistNames] are the
  /// artists the user already listened to (any case) and [excludeIds]
  /// artists already shown elsewhere. A seed that fails to load is skipped.
  Future<List<CompletionRecommendation>> build({
    required List<AlbumProgress> completed,
    Set<String> knownArtistNames = const {},
    Set<String> excludeIds = const {},
  }) async {
    final known = {for (final n in knownArtistNames) n.toLowerCase()};
    final shown = {...excludeIds};
    final seenSeedArtists = <String>{};
    final rows = <CompletionRecommendation>[];

    for (final album in completed) {
      if (rows.length >= maxSeeds) break;
      final name = album.artistName.trim();
      if (name.isEmpty || !seenSeedArtists.add(name.toLowerCase())) continue;

      List<Artist> related;
      try {
        final seed = await findArtist(name);
        if (seed == null || seed.id.isEmpty) continue;
        shown.add(seed.id);
        related = await relatedArtists(seed.id);
      } catch (_) {
        continue;
      }

      final picks = <Artist>[];
      for (final a in related) {
        if (picks.length >= perSeed) break;
        if (a.id.isEmpty || shown.contains(a.id)) continue;
        if (known.contains(a.name.toLowerCase())) continue;
        picks.add(a);
      }
      if (picks.length < minPerSeed) continue;
      shown.addAll(picks.map((a) => a.id));
      rows.add(CompletionRecommendation(album, picks));
    }
    return rows;
  }
}
