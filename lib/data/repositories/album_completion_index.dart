import 'package:flutter/foundation.dart';

import '../../domain/entities/album.dart';
import '../datasources/storage_service.dart';
import 'listened_tracks_repository.dart';

/// Knows how many tracks each album has and how many of them were listened,
/// so it can tell when an album is complete.
///
/// Track counts are kept in memory for any album the user looks at, but only
/// stored for albums with listened tracks, so storage stays bounded.
class AlbumCompletionIndex {
  final StorageService _storage;
  final List<ListenedTrackData> Function() _listenedTracks;
  final bool Function() _listenedLoaded;
  final VoidCallback _onChanged;

  AlbumCompletionIndex({
    required StorageService storage,
    required List<ListenedTrackData> Function() listenedTracks,
    required bool Function() listenedLoaded,
    required VoidCallback onChanged,
  })  : _storage = storage,
        _listenedTracks = listenedTracks,
        _listenedLoaded = listenedLoaded,
        _onChanged = onChanged;

  // albumId -> total tracks
  Map<String, int> _trackCounts = {};

  // Albums whose real track count was already requested this session.
  final Set<String> _trackCountRequests = {};

  // Listened tracks per album, rebuilt lazily after the listened tracks
  // change (see [invalidate]).
  bool _dirty = true;
  Map<String, int> _listenedByAlbum = {};

  // Test hook, reached through LibraryRepositoryImpl.
  Map<String, int> get trackCounts => _trackCounts;

  Future<void> load() async {
    _trackCounts = await _storage.getAlbumTrackCounts();
  }

  /// The listened tracks changed: per-album counts are rebuilt on next read.
  void invalidate() => _dirty = true;

  /// A new user: albums may be fetched again.
  void clearRequests() => _trackCountRequests.clear();

  void _ensureListenedByAlbum() {
    if (!_dirty) return;
    final byAlbum = <String, int>{};
    for (final t in _listenedTracks()) {
      if (t.albumId.isNotEmpty) {
        byAlbum[t.albumId] = (byAlbum[t.albumId] ?? 0) + 1;
      }
    }
    _listenedByAlbum = byAlbum;
    _dirty = false;
  }

  int listenedCountForAlbum(String albumId) {
    _ensureListenedByAlbum();
    return _listenedByAlbum[albumId] ?? 0;
  }

  int get listenedAlbumsCount {
    _ensureListenedByAlbum();
    return _listenedByAlbum.length;
  }

  int trackCount(String albumId) => _trackCounts[albumId] ?? 0;

  bool hasTrackCount(String albumId) => _trackCounts.containsKey(albumId);

  void register(String albumId, int count) {
    if (albumId.isEmpty || count <= 0) return;
    if (_trackCounts[albumId] == count) return;
    _trackCounts[albumId] = count;

    // Only persist if this album has listened tracks associated with it.
    // If not listened yet, keep in memory for active view without bloating storage.
    final hasListened = listenedCountForAlbum(albumId) > 0;
    if (hasListened) {
      prune(forceSave: true);
    } else if (_listenedLoaded() &&
        _trackCounts.length > _listenedTracks().length + 20) {
      // Memory safeguard: keep in-memory cache bounded when browsing many unlistened albums
      prune();
      _trackCounts[albumId] = count;
    }
    _onChanged();
  }

  /// Registers several album track counts with a single rebuild.
  void registerAll(Map<String, int> counts) {
    var changed = false;
    var touchesListened = false;
    for (final entry in counts.entries) {
      if (entry.key.isEmpty || entry.value <= 0) continue;
      if (_trackCounts[entry.key] == entry.value) continue;
      _trackCounts[entry.key] = entry.value;
      changed = true;
      if (listenedCountForAlbum(entry.key) > 0) touchesListened = true;
    }
    if (!changed) return;
    if (touchesListened) prune(forceSave: true);
    _onChanged();
  }

  /// Deezer's artist/albums listing omits nb_tracks, so an album can only be
  /// judged complete once its real track count is known. Requests that count
  /// for every album with listened tracks and no known total, at most once
  /// per album per session. Cheap enough to call from build, which also
  /// covers listened tracks that arrive after a screen loaded.
  void ensureTrackCounts(Iterable<Album> albums,
      Future<Album?> Function(String albumId) fetchAlbum) {
    if (!_listenedLoaded()) return;
    final known = <String, int>{};
    final toFetch = <String>[];
    for (final a in albums) {
      if (listenedCountForAlbum(a.id) == 0) continue;
      if (trackCount(a.id) > 0) continue;
      if (a.tracksCount > 0) {
        known[a.id] = a.tracksCount;
        continue;
      }
      if (_trackCountRequests.add(a.id)) toFetch.add(a.id);
    }
    if (known.isNotEmpty) {
      // Called from build: defer the notification to after the frame.
      Future.microtask(() => registerAll(known));
    }
    if (toFetch.isEmpty) return;

    Future.wait(toFetch.map(fetchAlbum)).then((results) {
      final counts = <String, int>{};
      for (final res in results) {
        if (res == null) continue;
        final count =
            res.tracks.isNotEmpty ? res.tracks.length : res.tracksCount;
        if (count > 0) counts[res.id] = count;
      }
      registerAll(counts);
    }).catchError((Object e) {
      debugPrint('[LibraryRepositoryImpl] ensureAlbumTrackCounts error: $e');
    });
  }

  bool isCompleted(String albumId, {int albumTracksCount = 0}) {
    if (albumId.isEmpty) return false;
    final listenedCount = listenedCountForAlbum(albumId);
    if (listenedCount == 0) return false;

    final registered = _trackCounts[albumId] ?? 0;
    final total = registered > 0 ? registered : albumTracksCount;

    if (total <= 0) return false;
    return listenedCount >= total;
  }

  /// Drops the counts of albums with no listened tracks left, and stores
  /// the rest when anything was dropped (or [forceSave]).
  void prune({bool forceSave = false}) {
    if (!_listenedLoaded() || _trackCounts.isEmpty) return;
    final activeAlbumIds = <String>{};
    for (final t in _listenedTracks()) {
      if (t.albumId.isNotEmpty) activeAlbumIds.add(t.albumId);
    }
    final before = _trackCounts.length;
    _trackCounts
        .removeWhere((albumId, _) => !activeAlbumIds.contains(albumId));
    if (_trackCounts.length < before || forceSave) {
      _storage.saveAlbumTrackCounts(_trackCounts);
      if (_trackCounts.length < before) {
        debugPrint(
            '[LibraryRepositoryImpl] Pruned ${before - _trackCounts.length} orphaned albumTrackCounts');
      }
    }
  }
}
