import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_progress.dart';
import '../datasources/storage_service.dart';
import 'listened_tracks_repository.dart';


final _log = Log.named('LibraryRepositoryImpl');

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

  /// Called when a newly-registered track count reveals a completed album
  /// that could not be detected before (the count was unknown). Wired up
  /// to fire the album_completed product event so it isn't lost.
  void Function(String albumId)? onAlbumCompleted;

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

  // Title, cover, artist and latest listen of each album with listened
  // tracks, for the recommendations; rebuilt lazily like the counts.
  bool _infoDirty = true;
  Map<String, _AlbumInfo> _albumInfo = {};

  // Test hook, reached through LibraryRepositoryImpl.
  Map<String, int> get trackCounts => _trackCounts;

  Future<void> load() async {
    _trackCounts = await _storage.getAlbumTrackCounts();
  }

  /// The listened tracks changed: per-album counts are rebuilt on next read.
  void invalidate() {
    _dirty = true;
    _infoDirty = true;
  }

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
    final wasComplete = isCompleted(albumId);
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
    if (!wasComplete && isCompleted(albumId)) {
      onAlbumCompleted?.call(albumId);
    }
    _onChanged();
  }

  /// Registers several album track counts with a single rebuild.
  void registerAll(Map<String, int> counts) {
    var changed = false;
    var touchesListened = false;
    final newlyCompleted = <String>[];
    for (final entry in counts.entries) {
      if (entry.key.isEmpty || entry.value <= 0) continue;
      if (_trackCounts[entry.key] == entry.value) continue;
      final wasComplete = isCompleted(entry.key);
      _trackCounts[entry.key] = entry.value;
      changed = true;
      if (listenedCountForAlbum(entry.key) > 0) touchesListened = true;
      if (!wasComplete && isCompleted(entry.key)) {
        newlyCompleted.add(entry.key);
      }
    }
    if (!changed) return;
    if (touchesListened) prune(forceSave: true);
    for (final albumId in newlyCompleted) {
      onAlbumCompleted?.call(albumId);
    }
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
      _log.severe('ensureAlbumTrackCounts error: $e');
    });
  }

  /// Albums with every song listened (those whose song count is known).
  int get completedAlbumsCount {
    _ensureListenedByAlbum();
    var n = 0;
    _trackCounts.forEach((albumId, total) {
      if (total > 0 && (_listenedByAlbum[albumId] ?? 0) >= total) n++;
    });
    return n;
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

  void _ensureAlbumInfo() {
    if (!_infoDirty) return;
    final info = <String, _AlbumInfo>{};
    for (final t in _listenedTracks()) {
      if (t.albumId.isEmpty) continue;
      final a = info.putIfAbsent(t.albumId, () => _AlbumInfo(t.albumTitle, t.coverUrl));
      a.listened++;
      if (a.coverUrl.isEmpty && t.coverUrl.isNotEmpty) a.coverUrl = t.coverUrl;
      final artist = t.artists.isNotEmpty ? t.artists.first : t.artistName;
      if (artist.isNotEmpty) a.artists[artist] = (a.artists[artist] ?? 0) + 1;
      final at = t.listenedAt;
      if (at != null && (a.lastListenedAt == null || at.isAfter(a.lastListenedAt!))) {
        a.lastListenedAt = at;
      }
    }
    _albumInfo = info;
    _infoDirty = false;
  }

  AlbumProgress _progressOf(String albumId, _AlbumInfo a) => AlbumProgress(
        albumId: albumId,
        title: a.title,
        artistName: a.mainArtist,
        coverUrl: a.coverUrl,
        listened: a.listened,
        total: _trackCounts[albumId] ?? 0,
        lastListenedAt: a.lastListenedAt,
      );

  static int _byRecency(AlbumProgress a, AlbumProgress b) {
    final at = a.lastListenedAt, bt = b.lastListenedAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  }

  /// Albums a few songs away from complete: at most [maxMissing] missing and
  /// at least [minShare] of them listened. Fewest missing first, then the
  /// most recently listened. Only albums whose song count is known count.
  List<AlbumProgress> almostComplete(
      {int maxMissing = 3, double minShare = 0.5, int limit = 10}) {
    _ensureAlbumInfo();
    final out = <AlbumProgress>[];
    _albumInfo.forEach((id, a) {
      final p = _progressOf(id, a);
      if (p.total <= 0 || p.isComplete) return;
      if (p.missing > maxMissing || p.share < minShare) return;
      out.add(p);
    });
    out.sort((a, b) {
      final byMissing = a.missing.compareTo(b.missing);
      return byMissing != 0 ? byMissing : _byRecency(a, b);
    });
    return out.take(limit).toList();
  }

  /// Completed albums, the most recently listened first.
  List<AlbumProgress> completed({int limit = 10}) {
    _ensureAlbumInfo();
    final out = <AlbumProgress>[];
    _albumInfo.forEach((id, a) {
      final p = _progressOf(id, a);
      if (p.isComplete) out.add(p);
    });
    out.sort(_byRecency);
    return out.take(limit).toList();
  }

  /// Requests the song count of the [limit] most recently listened albums
  /// that have none yet, so [almostComplete] and [completed] can judge them
  /// without the user opening each one. Same once-per-session rule as
  /// [ensureTrackCounts].
  void ensureRecentTrackCounts(
      Future<Album?> Function(String albumId) fetchAlbum,
      {int limit = 20}) {
    if (!_listenedLoaded()) return;
    _ensureAlbumInfo();
    final pending = <AlbumProgress>[];
    _albumInfo.forEach((id, a) {
      if ((_trackCounts[id] ?? 0) > 0 || _trackCountRequests.contains(id)) return;
      pending.add(_progressOf(id, a));
    });
    if (pending.isEmpty) return;
    pending.sort(_byRecency);
    ensureTrackCounts(
      pending.take(limit).map((p) => Album(
            id: p.albumId,
            title: p.title,
            coverUrl: p.coverUrl,
            artistId: '',
            artistName: p.artistName,
          )),
      fetchAlbum,
    );
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
        _log.fine('Pruned ${before - _trackCounts.length} orphaned albumTrackCounts');
      }
    }
  }
}

class _AlbumInfo {
  final String title;
  String coverUrl;
  int listened = 0;
  DateTime? lastListenedAt;

  // First artist of each listened song -> how many songs.
  final Map<String, int> artists = {};

  _AlbumInfo(this.title, this.coverUrl);

  /// The artist most of its songs are by.
  String get mainArtist {
    var best = '';
    var bestCount = 0;
    artists.forEach((name, n) {
      if (n > bestCount) {
        best = name;
        bestCount = n;
      }
    });
    return best;
  }
}
