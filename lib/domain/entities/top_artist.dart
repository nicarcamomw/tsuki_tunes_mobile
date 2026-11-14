/// An artist in the user's ranking, by how much they listen to, save and
/// visit them: (songs marked × 2) + plays + visits.
class TopArtistEntry {
  final String name;
  final int score;
  final int savedCount;
  final int visits;

  /// Times their songs really played (the phone's play log).
  final int plays;

  TopArtistEntry({
    required this.name,
    required this.score,
    required this.savedCount,
    required this.visits,
    this.plays = 0,
  });
}
