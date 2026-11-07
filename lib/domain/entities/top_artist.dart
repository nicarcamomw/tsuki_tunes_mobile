/// An artist in the user's ranking, by how much they listen to, save and
/// visit them.
class TopArtistEntry {
  final String name;
  final int score;
  final int savedCount;
  final int visits;

  TopArtistEntry({
    required this.name,
    required this.score,
    required this.savedCount,
    required this.visits,
  });
}
