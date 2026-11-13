import '../entities/album.dart';

/// How much of an artist's discography the user has listened to, which
/// lights up the mask on the artist's page.
///
/// Pure logic: which albums are the artist's own and whether an album is
/// complete are passed in, so it doesn't depend on the library or Deezer.
class ArtistCompletion {
  /// Own releases (albums, EPs, singles) heard from start to end.
  final int completed;

  /// Own releases, duplicate editions counted once.
  final int total;

  /// Every own release complete, and the whole discography loaded.
  final bool isComplete;

  const ArtistCompletion({required this.completed, required this.total, required this.isComplete});

  /// [albums] is the discography loaded so far; [loaded] says whether it's
  /// all of it (nothing loading and no page left). A release counts once,
  /// grouped by type and title (explicit and clean editions, re-uploads),
  /// and is complete when any of its editions is. Features and
  /// compilations ([isOwnRelease] false) don't count.
  factory ArtistCompletion.of(
    Iterable<Album> albums, {
    required bool Function(Album album) isOwnRelease,
    required bool Function(Album album) isAlbumCompleted,
    required bool loaded,
  }) {
    final groups = releaseGroups(albums, isOwnRelease: isOwnRelease);
    final completed = groups.where((group) => group.any(isAlbumCompleted)).length;
    return ArtistCompletion(
      completed: completed,
      total: groups.length,
      isComplete: loaded && groups.isNotEmpty && completed == groups.length,
    );
  }

  /// Own releases grouped by type + title, so that duplicate editions count
  /// as one release.
  static List<List<Album>> releaseGroups(
    Iterable<Album> albums, {
    required bool Function(Album album) isOwnRelease,
  }) {
    final groups = <String, List<Album>>{};
    for (final a in albums) {
      if (!isOwnRelease(a)) continue;
      final key = '${a.recordType}|${a.title.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(a);
    }
    return groups.values.toList();
  }
}
