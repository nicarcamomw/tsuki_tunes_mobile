/// How far the user got through an album: how many of its songs they
/// listened out of how many it has. Built from the listened songs, so the
/// title, cover and artist are the ones those songs carry.
class AlbumProgress {
  final String albumId;
  final String title;
  final String artistName;
  final String coverUrl;
  final int listened;

  /// The album's song count; 0 while it is not known.
  final int total;

  /// When the latest of its songs was listened, if known.
  final DateTime? lastListenedAt;

  const AlbumProgress({
    required this.albumId,
    required this.title,
    required this.artistName,
    required this.coverUrl,
    required this.listened,
    required this.total,
    this.lastListenedAt,
  });

  /// Songs left to complete it (0 when complete or the size is unknown).
  int get missing => total > listened ? total - listened : 0;

  bool get isComplete => total > 0 && listened >= total;

  /// Share listened, from 0 to 1 (0 while the size is unknown).
  double get share => total > 0 ? (listened / total).clamp(0.0, 1.0) : 0.0;

  @override
  bool operator ==(Object other) =>
      other is AlbumProgress &&
      other.albumId == albumId &&
      other.title == title &&
      other.artistName == artistName &&
      other.coverUrl == coverUrl &&
      other.listened == listened &&
      other.total == total &&
      other.lastListenedAt == lastListenedAt;

  @override
  int get hashCode => Object.hash(
      albumId, title, artistName, coverUrl, listened, total, lastListenedAt);
}
