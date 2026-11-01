import '../entities/track.dart';
import 'artist_names.dart';

/// An artist's songs split in two: the ones that are theirs (they are the
/// main artist) and the features, where they appear on someone else's song.
abstract final class ArtistFeatures {
  static ({List<Track> own, List<Track> features}) split(
    Iterable<Track> tracks, {
    required String artistId,
    required String artistName,
  }) {
    final own = <Track>[];
    final features = <Track>[];
    for (final t in tracks) {
      (isOwn(t, artistId: artistId, artistName: artistName) ? own : features)
          .add(t);
    }
    return (own: own, features: features);
  }

  static bool isOwn(
    Track t, {
    required String artistId,
    required String artistName,
  }) {
    if (t.artistId.isNotEmpty && artistId.isNotEmpty) {
      return t.artistId == artistId;
    }
    final main =
        t.contributors.isNotEmpty && t.contributors.first.name.isNotEmpty
        ? t.contributors.first.name
        : ArtistNames.primary(t.artistName);
    return main.trim().toLowerCase() == artistName.trim().toLowerCase();
  }
}
