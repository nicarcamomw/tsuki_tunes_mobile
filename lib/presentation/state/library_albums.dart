import 'package:collection/collection.dart' show mergeSort;
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

/// What plays when a song is picked in the library's album list: its whole
/// album in the album's order (so "previous" goes back through it), from
/// that song; then the albums after it in the list, so the music goes on.
/// [ordered] puts an album's songs in order. Stops adding albums once
/// [ahead] songs follow the picked one.
({List<ListenedTrackData> queue, int start}) libraryAlbumQueue(
  List<LibraryAlbumGroup> albums,
  int albumIndex,
  String trackId, {
  required List<ListenedTrackData> Function(LibraryAlbumGroup album) ordered,
  int ahead = 200,
}) {
  final first = ordered(albums[albumIndex]);
  final start = first.indexWhere((t) => t.trackId == trackId).clamp(0, first.length - 1);
  final queue = [...first];
  for (var i = albumIndex + 1; i < albums.length && queue.length - start - 1 < ahead; i++) {
    queue.addAll(ordered(albums[i]));
  }
  return (queue: queue, start: start);
}

/// The library as one list of songs, filtered and ordered like the album
/// list (and, like it, only redone when the songs, filter or order change).
class LibrarySongList {
  List<ListenedTrackData>? _source;
  String? _filter;
  String? _sortBy;
  List<ListenedTrackData> _view = const [];

  /// The songs matching [filter] (title, artist or album), ordered by
  /// [sortBy]: 'recent' (latest marked first), 'alpha' (title) or 'artist'
  /// (then album, then the order they were marked, oldest first).
  List<ListenedTrackData> view(
    List<ListenedTrackData> source, {
    required String filter,
    required String sortBy,
  }) {
    final f = filter.toLowerCase();
    if (identical(source, _source) && f == _filter && sortBy == _sortBy) return _view;
    final songs = f.isEmpty
        ? List<ListenedTrackData>.of(source)
        : source
            .where((t) =>
                t.title.toLowerCase().contains(f) ||
                t.artistName.toLowerCase().contains(f) ||
                t.albumTitle.toLowerCase().contains(f))
            .toList();
    switch (sortBy) {
      case 'alpha':
        mergeSort(songs, compare: (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'artist':
        // Oldest marked first within an album, as the album list plays it.
        final reversed = songs.reversed.toList();
        mergeSort(reversed, compare: (a, b) {
          final byArtist = a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
          return byArtist != 0 ? byArtist : a.albumTitle.toLowerCase().compareTo(b.albumTitle.toLowerCase());
        });
        songs
          ..clear()
          ..addAll(reversed);
      case 'recent':
      default:
        break; // the library lists the latest marked first already
    }
    _source = source;
    _filter = f;
    _sortBy = sortBy;
    return _view = List.unmodifiable(songs);
  }
}

/// Kept for the app's life, so returning to the library reuses the list.
final librarySongsProvider = Provider((ref) => LibrarySongList());

/// Kept for the app's life, so returning to the library reuses the list.
final libraryAlbumsProvider = Provider((ref) => LibraryAlbumList());
