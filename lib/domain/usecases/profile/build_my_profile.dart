import '../../entities/artist.dart';
import '../../entities/public_profile.dart';

/// The profile a user publishes, from their library: songs listened,
/// albums completed, distinct artists and the five artists with the most
/// songs listened (with a picture when they follow or love that artist).
/// A collaboration counts for each of its artists.
class BuildMyProfile {
  const BuildMyProfile();

  PublicProfile call({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? maskId,
    required bool isPublic,
    /// The artists of each listened song, one list per song.
    required Iterable<List<String>> listenedTrackArtists,
    required int albumsCompleted,
    Iterable<Artist> knownArtists = const [],
  }) {
    final perArtist = <String, int>{};
    final shown = <String, String>{}; // lowercase -> name as first seen
    var tracks = 0;
    for (final song in listenedTrackArtists) {
      tracks++;
      // An artist named twice in one song still counts that song once.
      final seen = <String>{};
      for (final raw in song) {
        final name = raw.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (!seen.add(key)) continue;
        shown.putIfAbsent(key, () => name);
        perArtist[key] = (perArtist[key] ?? 0) + 1;
      }
    }
    final pictures = {
      for (final a in knownArtists)
        if (a.pictureUrl.isNotEmpty) a.name.trim().toLowerCase(): a.pictureUrl,
    };
    final ranked = perArtist.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : shown[a.key]!.compareTo(shown[b.key]!));

    return PublicProfile(
      uid: uid,
      displayName: displayName.trim().isEmpty ? 'Tsuki' : displayName.trim(),
      photoUrl: photoUrl,
      maskId: maskId,
      isPublic: isPublic,
      stats: ProfileStats(tracks: tracks, albums: albumsCompleted, artists: perArtist.length),
      topArtists: [
        for (final e in ranked.take(PublicProfile.topArtistsShown))
          TopArtist(name: shown[e.key]!, count: e.value, pictureUrl: pictures[e.key]),
      ],
    );
  }
}
