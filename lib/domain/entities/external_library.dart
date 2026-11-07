/// A playlist in another service (Spotify) the user can bring into Tsuki.
class ExternalPlaylist {
  const ExternalPlaylist({required this.id, required this.name, required this.total, this.imageUrl, this.liked = false});

  final String id;
  final String name;

  /// How many songs it has.
  final int total;
  final String? imageUrl;

  /// The saved songs (Spotify's "Liked Songs"), not a playlist proper.
  final bool liked;
}

/// A song as the other service describes it, to find it in Tsuki's catalog.
class ExternalTrack {
  const ExternalTrack({required this.title, required this.artists, this.isrc, this.durationMs = 0});

  final String title;
  final List<String> artists;

  /// The recording's international code: the surest match.
  final String? isrc;
  final int durationMs;
}
