import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/listened_track.dart';

/// An album as the library lists it: its listened songs and the latest
/// time one of them was heard.
class LibraryAlbumGroup {
  final String albumId;
  final String albumTitle;
  final String artistName;
  final String coverUrl;
  final List<ListenedTrackData> tracks;
  final DateTime? latestListened;

  const LibraryAlbumGroup({
    required this.albumId,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
    required this.tracks,
    this.latestListened,
  });
}

/// The library screen's album list: grouped, filtered and sorted only when
/// something it depends on changes (the listened songs, the filter text, the
/// order). Every other rebuild, like scrolling loading the next page, gets
/// the same list back without redoing any of it.
class LibraryAlbumList {
  List<ListenedTrackData>? _source;
  List<LibraryAlbumGroup> _groups = const [];

  String? _filter;
  String? _sortBy;
  List<LibraryAlbumGroup> _view = const [];

  /// Every album, in the order its first song appears. Rebuilt when the
  /// listened songs change (the library hands out a new list then).
  List<LibraryAlbumGroup> groups(List<ListenedTrackData> source) {
    _ensureGroups(source);
    return _groups;
  }

  /// The albums matching [filter] (title or artist), ordered by [sortBy]:
  /// 'recent' (latest listen first), 'alpha' (title) or 'artist'.
  List<LibraryAlbumGroup> view(
    List<ListenedTrackData> source, {
    required String filter,
    required String sortBy,
  }) {
    final regrouped = _ensureGroups(source);
    final f = filter.toLowerCase();
    if (!regrouped && f == _filter && sortBy == _sortBy) return _view;

    var albums = f.isEmpty
        ? List<LibraryAlbumGroup>.of(_groups)
        : _groups
            .where((g) =>
                g.albumTitle.toLowerCase().contains(f) ||
                g.artistName.toLowerCase().contains(f))
            .toList();
    switch (sortBy) {
      case 'alpha':
        albums.sort((a, b) => a.albumTitle.toLowerCase().compareTo(b.albumTitle.toLowerCase()));
      case 'artist':
        albums.sort((a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
      case 'recent':
      default:
        final never = DateTime(2000);
        albums.sort((a, b) => (b.latestListened ?? never).compareTo(a.latestListened ?? never));
    }
    albums = List.unmodifiable(albums);

    _filter = f;
    _sortBy = sortBy;
    _view = albums;
    return albums;
  }

  /// Returns whether it grouped again.
  bool _ensureGroups(List<ListenedTrackData> source) {
    if (identical(source, _source)) return false;
    final tracksByKey = <String, List<ListenedTrackData>>{};
    final firstOf = <String, ListenedTrackData>{};
    final latest = <String, DateTime>{};
    for (final t in source) {
      final key = t.albumId.isNotEmpty
          ? t.albumId
          : t.albumTitle.isNotEmpty
              ? t.albumTitle
              : 'unknown';
      firstOf.putIfAbsent(key, () => t);
      (tracksByKey[key] ??= []).add(t);
      final at = t.listenedAt;
      if (at != null) {
        final current = latest[key];
        if (current == null || at.isAfter(current)) latest[key] = at;
      }
    }
    _groups = List.unmodifiable([
      for (final entry in firstOf.entries)
        LibraryAlbumGroup(
          albumId: entry.value.albumId,
          albumTitle: entry.value.albumTitle,
          artistName: entry.value.artistName,
          coverUrl: entry.value.coverUrl,
          tracks: List.unmodifiable(tracksByKey[entry.key]!),
          latestListened: latest[entry.key],
        ),
    ]);
    _source = source;
    return true;
  }
}

/// Kept for the app's life, so returning to the library reuses the list.
final libraryAlbumsProvider = Provider((ref) => LibraryAlbumList());
