/// A song listeners play alongside another one, by name only (it still has
/// to be found in the catalog to play). [match] goes from 0 to 1.
class SimilarTrack {
  final String artist;
  final String title;
  final double match;
  const SimilarTrack(this.artist, this.title, this.match);
}
