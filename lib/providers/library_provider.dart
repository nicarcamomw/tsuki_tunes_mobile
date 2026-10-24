import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';

class ListenedTrackData {
  final String trackId;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumId;
  final String coverUrl;
  final String previewUrl;
  final int duration;
  final DateTime? listenedAt;

  ListenedTrackData({
    required this.trackId,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumId,
    required this.coverUrl,
    this.previewUrl = '',
    required this.duration,
    this.listenedAt,
  });

  factory ListenedTrackData.fromFirestore(Map<String, dynamic> data,
      {String? docId}) {
    DateTime? listened;
    final rawListened = data['listenedAt'];
    if (rawListened is Timestamp) {
      listened = rawListened.toDate();
    } else if (rawListened is Map) {
      final sec = rawListened['seconds'] ?? rawListened['_seconds'];
      if (sec is num) {
        listened = DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
      }
    } else if (rawListened is String) {
      listened = DateTime.tryParse(rawListened);
    }

    final tid = data['trackId']?.toString() ?? docId ?? '';
    final aid = data['albumId']?.toString() ?? '';
    final dur =
        data['duration'] is num ? (data['duration'] as num).toInt() : 0;

    return ListenedTrackData(
      trackId: tid,
      title: data['title']?.toString() ?? '',
      artistName: data['artistName']?.toString() ?? '',
      albumTitle: data['albumTitle']?.toString() ?? '',
      albumId: aid,
      coverUrl: data['coverUrl']?.toString() ?? '',
      previewUrl: data['previewUrl']?.toString() ?? '',
      duration: dur,
      listenedAt: listened,
    );
  }

  factory ListenedTrackData.fromJson(Map<String, dynamic> json) {
    DateTime? listened;
    if (json['listenedAt'] != null) {
      listened = DateTime.tryParse(json['listenedAt'].toString());
    }
    return ListenedTrackData(
      trackId: json['trackId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artistName: json['artistName']?.toString() ?? '',
      albumTitle: json['albumTitle']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString() ?? '',
      duration:
          json['duration'] is num ? (json['duration'] as num).toInt() : 0,
      listenedAt: listened,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
        'listenedAt': listenedAt?.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
        'listenedAt': FieldValue.serverTimestamp(),
      };
}

class TopArtistEntry {
  final String name;
  final int score;
  final int savedCount;
  final int visits;

  TopArtistEntry({
    required this.name,
    required this.score,
    required this.savedCount,
    required this.visits,
  });
}

class LibraryProvider extends ChangeNotifier {
  final StorageService _storage;
  final FirebaseService _firebase;

  // Local data
  List<Track> _favoriteTracks = [];
  List<Track> _recentTracks = [];
  List<Artist> _favoriteArtists = [];
  bool _isLoaded = false;

  // Firestore listened tracks
  List<ListenedTrackData> _listenedTracks = [];
  Set<String> _listenedTrackIds = {};
  int _totalTracksCount = 0;
  bool _syncing = false;
  int _syncCount = 0;

  /// Last error from a mark/unmark Firestore write, cleared on success.
  /// The UI can watch this to show a snackbar when a save fails.
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  /// True when in-memory state has changes not yet confirmed by Firestore.
  /// The delta listener clears this and saves the cache once the server
  /// confirms (hasPendingWrites == false).
  bool _cacheDirty = false;

  // Artist visits
  Map<String, int> _artistVisits = {};

  // Album track counts cache (albumId -> totalTracks)
  Map<String, int> _albumTrackCounts = {};
  bool _listenedTracksLoaded = false;

  // Followed artists (Firestore-synced)
  List<Artist> _followedArtists = [];
  Set<String> _followedArtistIds = {};

  // Firestore subscriptions
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _deletionsSubscription;
  StreamSubscription? _followedArtistsSubscription;

  // Public getters
  List<Track> get favoriteTracks => _favoriteTracks;
  List<Track> get recentTracks => _recentTracks;
  List<Artist> get favoriteArtists => _favoriteArtists;
  bool get isLoaded => _isLoaded;

  List<ListenedTrackData> get listenedTracks => List.unmodifiable(_listenedTracks);
  Set<String> get listenedTrackIds => Set.unmodifiable(_listenedTrackIds);
  int get totalTracksCount => _totalTracksCount;
  bool get syncing => _syncing;
  Map<String, int> get artistVisits => Map.unmodifiable(_artistVisits);
  List<Artist> get followedArtists => List.unmodifiable(_followedArtists);
  Set<String> get followedArtistIds => Set.unmodifiable(_followedArtistIds);
  bool isArtistFollowed(String artistId) => _followedArtistIds.contains(artistId);

  int getAlbumTracksCount(String albumId) => _albumTrackCounts[albumId] ?? 0;
  bool get listenedTracksLoaded => _listenedTracksLoaded;
  @visibleForTesting
  Map<String, int> get albumTrackCounts => _albumTrackCounts;

  void registerAlbumTrackCount(String albumId, int count) {
    if (albumId.isEmpty || count <= 0) return;
    if (_albumTrackCounts[albumId] == count) return;
    _albumTrackCounts[albumId] = count;

    // Only persist if this album has listened tracks associated with it.
    // If not listened yet, keep in memory for active view without bloating storage.
    final hasListened = listenedCountForAlbum(albumId) > 0;
    if (hasListened) {
      _pruneAlbumTrackCounts(forceSave: true);
    } else if (_listenedTracksLoaded &&
        _albumTrackCounts.length > _listenedTracks.length + 20) {
      // Memory safeguard: keep in-memory cache bounded when browsing many unlistened albums
      _pruneAlbumTrackCounts();
      _albumTrackCounts[albumId] = count;
    }
    notifyListeners();
  }

  // Derived indexes over _listenedTracks, rebuilt lazily after any change.
  // Every mutation ends in notifyListeners(), which marks them dirty.
  bool _indexesDirty = true;
  Map<String, int> _listenedCountByAlbum = {};
  int _uniqueArtistsCount = 0;

  @override
  void notifyListeners() {
    _indexesDirty = true;
    super.notifyListeners();
  }

  void _ensureIndexes() {
    if (!_indexesDirty) return;
    final byAlbum = <String, int>{};
    final artists = <String>{};
    for (final t in _listenedTracks) {
      if (t.albumId.isNotEmpty) {
        byAlbum[t.albumId] = (byAlbum[t.albumId] ?? 0) + 1;
      }
      if (t.artistName.isNotEmpty) artists.add(t.artistName);
    }
    _listenedCountByAlbum = byAlbum;
    _uniqueArtistsCount = artists.length;
    _indexesDirty = false;
  }

  int listenedCountForAlbum(String albumId) {
    _ensureIndexes();
    return _listenedCountByAlbum[albumId] ?? 0;
  }

  /// Registers several album track counts with a single rebuild.
  void registerAlbumTrackCounts(Map<String, int> counts) {
    var changed = false;
    var touchesListened = false;
    for (final entry in counts.entries) {
      if (entry.key.isEmpty || entry.value <= 0) continue;
      if (_albumTrackCounts[entry.key] == entry.value) continue;
      _albumTrackCounts[entry.key] = entry.value;
      changed = true;
      if (listenedCountForAlbum(entry.key) > 0) touchesListened = true;
    }
    if (!changed) return;
    if (touchesListened) _pruneAlbumTrackCounts(forceSave: true);
    notifyListeners();
  }

  // Albums whose real track count was already requested this session.
  final Set<String> _trackCountRequests = {};

  /// Deezer's artist/albums listing omits nb_tracks, so an album can only be
  /// judged complete once its real track count is known. Requests that count
  /// for every album with listened tracks and no known total, at most once
  /// per album per session. Cheap enough to call from build, which also
  /// covers listened tracks that arrive after a screen loaded.
  void ensureAlbumTrackCounts(Iterable<Album> albums,
      Future<Album?> Function(String albumId) fetchAlbum) {
    if (!_listenedTracksLoaded) return;
    final known = <String, int>{};
    final toFetch = <String>[];
    for (final a in albums) {
      if (listenedCountForAlbum(a.id) == 0) continue;
      if (getAlbumTracksCount(a.id) > 0) continue;
      if (a.tracksCount > 0) {
        known[a.id] = a.tracksCount;
        continue;
      }
      if (_trackCountRequests.add(a.id)) toFetch.add(a.id);
    }
    if (known.isNotEmpty) {
      // Called from build: defer the notification to after the frame.
      Future.microtask(() => registerAlbumTrackCounts(known));
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
      registerAlbumTrackCounts(counts);
    }).catchError((Object e) {
      debugPrint('[LibraryProvider] ensureAlbumTrackCounts error: $e');
    });
  }

  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0}) {
    if (albumId.isEmpty) return false;
    final listenedCount = listenedCountForAlbum(albumId);
    if (listenedCount == 0) return false;

    final registered = _albumTrackCounts[albumId] ?? 0;
    final total = registered > 0 ? registered : albumTracksCount;

    if (total <= 0) return false;
    return listenedCount >= total;
  }

  int get uniqueArtistsCount {
    _ensureIndexes();
    return _uniqueArtistsCount;
  }

  int get uniqueAlbumsCount {
    _ensureIndexes();
    return _listenedCountByAlbum.length;
  }

  LibraryProvider({FirebaseService? firebase, StorageService? storage})
      : _firebase = firebase ?? FirebaseService(),
        _storage = storage ?? StorageService() {
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    _favoriteTracks = await _storage.getFavoriteTracks();
    _recentTracks = await _storage.getRecentTracks();
    _favoriteArtists = await _storage.getFavoriteArtists();
    _artistVisits = await _storage.getArtistVisits();
    _albumTrackCounts = await _storage.getAlbumTrackCounts();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> refreshData() async {
    await _loadLocalData();
    if (_currentUid != null) {
      await connectToFirestore(_currentUid!);
    }
  }

  String? _currentUid;
  String? get currentUid => _currentUid;

  @visibleForTesting
  bool bypassAuthForTesting = false;

  @visibleForTesting
  void setUidForTesting(String? uid) {
    _currentUid = uid;
  }

  @visibleForTesting
  Future<void> Function(List<ListenedTrackData> chunk, String uid)?
      markAlbumChunkHandlerForTesting;

  @visibleForTesting
  Future<void> Function(List<String> chunkIds, String uid)?
      unmarkAlbumChunkHandlerForTesting;

  bool _canSyncToFirestore(String uid) {
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    if (bypassAuthForTesting) return true;
    if (!_firebase.isSignedIn) return false;
    return true;
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _tracksSubscription != null) return;
    _currentUid = uid;

    unawaited(_tracksSubscription?.cancel());
    unawaited(_deletionsSubscription?.cancel());
    unawaited(_followedArtistsSubscription?.cancel());

    final db = _firebase.db;
    final userDoc = db.collection('users').doc(uid);
    final tracksCol = userDoc.collection('listenedTracks');

    // 1. Instant local cache restore (0ms cold start — tracks never disappear)
    try {
      final cached = await _storage.getCachedListenedTracks(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _listenedTracks =
            cached.map((e) => ListenedTrackData.fromJson(e)).toList();
        _listenedTrackIds = _listenedTracks.map((t) => t.trackId).toSet();
        _totalTracksCount = _listenedTracks.length;
        _listenedTracksLoaded = true;
        _pruneAlbumTrackCounts();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] Error restoring cached tracks: $e');
    }

    // 2. Full fetch only when there is no cache or the last full sync is
    //    older than a day. Otherwise the cache plus the delta listeners below
    //    are enough, so a cold start costs a handful of reads instead of one
    //    per listened track. The daily full fetch also picks up deletions
    //    made by clients that don't write the deletion log (the web app).
    final lastFullSync = await _storage.getLastListenedFullSync(uid);
    if (_currentUid != uid) return;
    final now = DateTime.now();
    final needsFullSync = _listenedTracks.isEmpty ||
        lastFullSync == null ||
        now.difference(lastFullSync) > _fullSyncInterval;
    DateTime deletionsSince =
        (lastFullSync ?? now).subtract(const Duration(minutes: 5));

    if (needsFullSync) {
      try {
        final fetchStartedAt = DateTime.now();
        final snapshot =
            await tracksCol.orderBy('listenedAt', descending: true).get();
        if (_currentUid != uid) return;

        _listenedTracks = snapshot.docs
            .map((doc) =>
                ListenedTrackData.fromFirestore(doc.data(), docId: doc.id))
            .toList();
        _listenedTrackIds = _listenedTracks.map((t) => t.trackId).toSet();
        _totalTracksCount = _listenedTracks.length;
        _listenedTracksLoaded = true;
        notifyListeners();

        unawaited(_storage.saveCachedListenedTracks(
          uid,
          _listenedTracks.map((t) => t.toJson()).toList(),
        ));
        unawaited(_storage.saveLastListenedFullSync(uid, fetchStartedAt));
        deletionsSince = fetchStartedAt.subtract(const Duration(minutes: 5));
        _pruneAlbumTrackCounts();
        _reconcileServerStats(userDoc, _listenedTracks.length);
        _pruneDeletionLog(userDoc);
      } catch (e) {
        debugPrint('[LibraryProvider] Initial Firestore fetch error: $e');
      }
    }

    // 3. Delta listener — only docs newer than the latest known timestamp.
    //    The margin absorbs device clock skew in optimistic local entries.
    DateTime? deltaBoundary;
    for (final t in _listenedTracks) {
      if (t.listenedAt != null &&
          (deltaBoundary == null || t.listenedAt!.isAfter(deltaBoundary))) {
        deltaBoundary = t.listenedAt;
      }
    }
    if (deltaBoundary != null) {
      if (deltaBoundary.isAfter(now)) deltaBoundary = now;
      deltaBoundary = deltaBoundary.subtract(const Duration(minutes: 10));
    }
    final deltaQuery = deltaBoundary != null
        ? tracksCol
            .where('listenedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(deltaBoundary))
            .orderBy('listenedAt', descending: true)
        : tracksCol.orderBy('listenedAt', descending: true);

    _tracksSubscription = deltaQuery.snapshots().listen((snapshot) {
      if (_currentUid != uid) return;

      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;

        final data =
            ListenedTrackData.fromFirestore(docData, docId: change.doc.id);

        if (change.type == DocumentChangeType.removed) {
          if (_listenedTrackIds.remove(data.trackId)) {
            _listenedTracks.removeWhere((t) => t.trackId == data.trackId);
            changed = true;
          }
        } else {
          final idx =
              _listenedTracks.indexWhere((t) => t.trackId == data.trackId);
          if (idx != -1) {
            _listenedTracks[idx] = data;
          } else {
            _listenedTracks.insert(0, data);
            _listenedTrackIds.add(data.trackId);
          }
          changed = true;
        }
      }

      if (changed) {
        _totalTracksCount = _listenedTracks.length;
        _pruneAlbumTrackCounts();
        notifyListeners();
        _cacheDirty = true;
      }

      // Only persist to SharedPreferences cache once the server has
      // confirmed all pending writes. This prevents phantom tracks from
      // being cached before they actually reach Firestore. When
      // hasPendingWrites transitions from true to false the listener
      // fires again, so the save is never lost.
      if (!snapshot.metadata.hasPendingWrites && _cacheDirty) {
        _cacheDirty = false;
        _storage.saveCachedListenedTracks(
          uid,
          _listenedTracks.map((t) => t.toJson()).toList(),
        );
      }
    }, onError: (e) {
      debugPrint('[LibraryProvider] Firestore delta sync error: $e');
    });

    // 4. Deletion log — unmarks of tracks older than the delta boundary never
    //    show up as "removed" in the delta query, so unmarks also write
    //    listenedDeletions/{trackId} and other devices apply them from here.
    _deletionsSubscription = userDoc
        .collection('listenedDeletions')
        .where('deletedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(deletionsSince))
        .snapshots()
        .listen((snapshot) {
      if (_currentUid != uid) return;
      bool changed = false;
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final data = change.doc.data();
        final rawDeletedAt = data?['deletedAt'];
        // Pending local write (this device's own unmark): already applied.
        if (rawDeletedAt is! Timestamp) continue;
        if (applyRemoteDeletion(change.doc.id, rawDeletedAt.toDate())) {
          changed = true;
        }
      }
      if (changed) _onListenedTracksChanged(uid);
    }, onError: (e) {
      debugPrint('[LibraryProvider] Firestore deletions sync error: $e');
    });

    // 5. Followed artists — cache restore + full fetch + listener
    try {
      final cached = await _storage.getCachedFollowedArtists(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _followedArtists = cached.map((e) => Artist.fromStorage(e)).toList();
        _followedArtistIds = _followedArtists.map((a) => a.id).toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] Error restoring cached followed artists: $e');
    }

    final followedCol = userDoc.collection('followedArtists');
    try {
      final snapshot = await followedCol.get();
      if (_currentUid != uid) return;
      _followedArtists = snapshot.docs
          .map((doc) => Artist.fromStorage(doc.data()))
          .toList();
      _followedArtistIds = _followedArtists.map((a) => a.id).toSet();
      notifyListeners();
      unawaited(_storage.saveCachedFollowedArtists(
        uid,
        _followedArtists.map((a) => a.toJson()).toList(),
      ));
    } catch (e) {
      debugPrint('[LibraryProvider] Followed artists fetch error: $e');
    }

    _followedArtistsSubscription = followedCol.snapshots().listen((snapshot) {
      if (_currentUid != uid) return;
      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;
        final artist = Artist.fromStorage(docData);
        if (change.type == DocumentChangeType.removed) {
          if (_followedArtistIds.remove(artist.id)) {
            _followedArtists.removeWhere((a) => a.id == artist.id);
            changed = true;
          }
        } else {
          if (!_followedArtistIds.contains(artist.id)) {
            _followedArtists.add(artist);
            _followedArtistIds.add(artist.id);
            changed = true;
          }
        }
      }
      if (changed) {
        notifyListeners();
        _storage.saveCachedFollowedArtists(
          uid,
          _followedArtists.map((a) => a.toJson()).toList(),
        );
      }
    }, onError: (e) {
      debugPrint('[LibraryProvider] Followed artists sync error: $e');
    });
  }

  static const Duration _fullSyncInterval = Duration(hours: 4);
  static const Duration _deletionLogRetention = Duration(days: 7);

  /// Updates derived state and persists cache. Called after a confirmed
  /// change to _listenedTracks (from the deletion log listener or
  /// from a rollback). The delta listener handles its own cache saves
  /// gated on hasPendingWrites, so it calls the inline equivalent.
  void _onListenedTracksChanged(String uid) {
    _totalTracksCount = _listenedTracks.length;
    _pruneAlbumTrackCounts();
    notifyListeners();
    _storage.saveCachedListenedTracks(
      uid,
      _listenedTracks.map((t) => t.toJson()).toList(),
    );
  }

  /// Applies an unmark made on another device. A track re-marked after the
  /// deletion (newer listenedAt) is kept. Returns whether anything changed.
  @visibleForTesting
  bool applyRemoteDeletion(String trackId, DateTime deletedAt) {
    final idx = _listenedTracks.indexWhere((t) => t.trackId == trackId);
    if (idx == -1) return false;
    final listenedAt = _listenedTracks[idx].listenedAt;
    if (listenedAt != null && listenedAt.isAfter(deletedAt)) return false;
    _listenedTracks.removeAt(idx);
    _listenedTrackIds.remove(trackId);
    return true;
  }

  /// stats.totalTracks is kept with client-side increments (the web app
  /// reads it), which drift when two devices mark the same track. The full
  /// sync knows the real count, so it rewrites it.
  void _reconcileServerStats(
      DocumentReference<Map<String, dynamic>> userDoc, int count) {
    userDoc.set({
      'stats': {'totalTracks': count},
    }, SetOptions(merge: true)).catchError((Object e) {
      debugPrint('[LibraryProvider] stats reconcile failed: $e');
    });
  }

  /// Keeps the deletion log short: entries only matter until every device
  /// has done a full sync, which happens at least daily while in use.
  void _pruneDeletionLog(DocumentReference<Map<String, dynamic>> userDoc) {
    final cutoff = DateTime.now().subtract(_deletionLogRetention);
    userDoc
        .collection('listenedDeletions')
        .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
        .limit(400)
        .get()
        .then((snap) async {
      if (snap.docs.isEmpty) return;
      final batch = _firebase.db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }).catchError((Object e) {
      debugPrint('[LibraryProvider] deletion log prune failed: $e');
    });
  }

  void _pruneAlbumTrackCounts({bool forceSave = false}) {
    if (!_listenedTracksLoaded || _albumTrackCounts.isEmpty) return;
    final activeAlbumIds = <String>{};
    for (final t in _listenedTracks) {
      if (t.albumId.isNotEmpty) activeAlbumIds.add(t.albumId);
    }
    final before = _albumTrackCounts.length;
    _albumTrackCounts
        .removeWhere((albumId, _) => !activeAlbumIds.contains(albumId));
    if (_albumTrackCounts.length < before || forceSave) {
      _storage.saveAlbumTrackCounts(_albumTrackCounts);
      if (_albumTrackCounts.length < before) {
        debugPrint(
            '[LibraryProvider] Pruned ${before - _albumTrackCounts.length} orphaned albumTrackCounts');
      }
    }
  }

  @visibleForTesting
  void pruneAlbumTrackCounts({bool forceSave = false}) =>
      _pruneAlbumTrackCounts(forceSave: forceSave);

  @visibleForTesting
  void setListenedTracksLoadedForTesting(bool loaded) {
    _listenedTracksLoaded = loaded;
  }

  @visibleForTesting
  void setListenedTracksForTesting(List<ListenedTrackData> tracks) {
    _listenedTracks = List.from(tracks);
    _indexesDirty = true;
    _listenedTrackIds = tracks.map((t) => t.trackId).toSet();
    _totalTracksCount = tracks.length;
    _listenedTracksLoaded = true;
  }

  void disconnectFirestore() {
    _currentUid = null;
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
    _followedArtistsSubscription?.cancel();
    _tracksSubscription = null;
    _listenedTracks = [];
    _listenedTrackIds = {};
    _trackCountRequests.clear();
    _totalTracksCount = 0;
    _listenedTracksLoaded = false;
    _cacheDirty = false;
    _lastSyncError = null;
    _followedArtists = [];
    _followedArtistIds = {};
    notifyListeners();
  }

  // --- Listened tracks (Firestore) ---

  bool isTrackListened(String trackId) => _listenedTrackIds.contains(trackId);

  Future<void> markTrack(Track track) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (_listenedTrackIds.contains(track.id)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update — UI reflects the mark immediately.
    final data = ListenedTrackData(
      trackId: track.id,
      title: track.title,
      artistName: track.fullArtistName,
      albumTitle: track.albumTitle,
      albumId: track.albumId,
      coverUrl: track.coverUrl,
      duration: track.durationSeconds,
      previewUrl: track.previewUrl,
      listenedAt: DateTime.now(),
    );
    _listenedTracks.add(data);
    _listenedTrackIds.add(track.id);
    _totalTracksCount = _listenedTracks.length;
    if (track.albumId.isNotEmpty && _albumTrackCounts.containsKey(track.albumId)) {
      _pruneAlbumTrackCounts(forceSave: true);
    }
    _lastSyncError = null;
    notifyListeners();

    // NOTE: cache is NOT saved here — it is saved by the delta listener
    // only after Firestore confirms the write, preventing phantom tracks
    // that disappear on the next full sync.

    _startSync();
    try {
      await _commitMarkBatch(uid, track.id, data);
    } catch (e) {
      // Retry once after a short delay (handles rate-limit / transient errors)
      try {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _commitMarkBatch(uid, track.id, data);
      } catch (retryError) {
        debugPrint('[LibraryProvider] markTrack rollback — Firestore failed after retry: $retryError');
        _listenedTracks = prevTracks;
        _listenedTrackIds = prevIds;
        _totalTracksCount = prevCount;
        _lastSyncError = 'mark_failed';
        notifyListeners();
        // Save the rolled-back (correct) state to cache.
        unawaited(_storage.saveCachedListenedTracks(
          uid,
          _listenedTracks.map((t) => t.toJson()).toList(),
        ));
      }
    } finally {
      _endSync();
    }
  }

  /// Writes one listened track + stats update to Firestore in a single batch.
  Future<void> _commitMarkBatch(
      String uid, String trackId, ListenedTrackData data) async {
    final db = _firebase.db;
    final userDoc = db.collection('users').doc(uid);
    final batch = db.batch();
    batch.set(
      userDoc.collection('listenedTracks').doc(trackId),
      data.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      userDoc,
      {
        'stats': {'totalTracks': FieldValue.increment(1)},
        'lastSubWrite': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    _lastSyncError = null;
  }

  Future<void> unmarkTrack(String trackId) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (!_listenedTrackIds.contains(trackId)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update
    _listenedTracks.removeWhere((t) => t.trackId == trackId);
    _listenedTrackIds.remove(trackId);
    _totalTracksCount = _listenedTracks.length;
    _pruneAlbumTrackCounts();
    _lastSyncError = null;
    notifyListeners();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    _startSync();
    try {
      await _commitUnmarkBatch(uid, trackId);
    } catch (e) {
      // Retry once after a short delay
      try {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _commitUnmarkBatch(uid, trackId);
      } catch (retryError) {
        debugPrint('[LibraryProvider] unmarkTrack rollback — Firestore failed after retry: $retryError');
        _listenedTracks = prevTracks;
        _listenedTrackIds = prevIds;
        _totalTracksCount = prevCount;
        _lastSyncError = 'unmark_failed';
        notifyListeners();
        unawaited(_storage.saveCachedListenedTracks(
          uid,
          _listenedTracks.map((t) => t.toJson()).toList(),
        ));
      }
    } finally {
      _endSync();
    }
  }

  /// Deletes one listened track + writes deletion log + stats in a single batch.
  Future<void> _commitUnmarkBatch(String uid, String trackId) async {
    final db = _firebase.db;
    final userDoc = db.collection('users').doc(uid);
    final batch = db.batch();
    batch.delete(userDoc.collection('listenedTracks').doc(trackId));
    batch.set(userDoc.collection('listenedDeletions').doc(trackId), {
      'deletedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      userDoc,
      {
        'stats': {'totalTracks': FieldValue.increment(-1)},
        'lastSubWrite': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    _lastSyncError = null;
  }

  Future<void> markAlbumTracks(List<Track> tracks,
      {String? albumId, int? totalTracks}) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;

    if (albumId != null && totalTracks != null && totalTracks > 0) {
      registerAlbumTrackCount(albumId, totalTracks);
    } else if (tracks.isNotEmpty && tracks.first.albumId.isNotEmpty) {
      registerAlbumTrackCount(tracks.first.albumId, tracks.length);
    }

    final seen = <String>{};
    final toMark = <Track>[];
    for (final t in tracks) {
      if (!_listenedTrackIds.contains(t.id) && seen.add(t.id)) {
        toMark.add(t);
      }
    }
    if (toMark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update
    final newData = toMark
        .map((t) => ListenedTrackData(
              trackId: t.id,
              title: t.title,
              artistName: t.fullArtistName,
              albumTitle: t.albumTitle,
              albumId: t.albumId,
              coverUrl: t.coverUrl,
              previewUrl: t.previewUrl,
              duration: t.durationSeconds,
              listenedAt: DateTime.now(),
            ))
        .toList();
    _listenedTracks.addAll(newData);
    _listenedTrackIds.addAll(toMark.map((t) => t.id));
    _totalTracksCount = _listenedTracks.length;
    _pruneAlbumTrackCounts(forceSave: true);
    _lastSyncError = null;
    notifyListeners();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    _startSync();
    final committedData = <ListenedTrackData>[];
    try {
      final customHandler = markAlbumChunkHandlerForTesting;
      final db = customHandler == null ? _firebase.db : null;
      final userDoc = db?.collection('users').doc(uid);
      const batchLimit = 450;

      for (var i = 0; i < newData.length; i += batchLimit) {
        if (i > 0) await Future.delayed(const Duration(milliseconds: 1100));
        final chunk = newData.sublist(
            i, i + batchLimit > newData.length ? newData.length : i + batchLimit);

        if (customHandler != null) {
          await customHandler(chunk, uid);
        } else if (db != null && userDoc != null) {
          final batch = db.batch();
          for (final data in chunk) {
            batch.set(
              userDoc.collection('listenedTracks').doc(data.trackId),
              data.toFirestore(),
              SetOptions(merge: true),
            );
          }
          batch.set(
            userDoc,
            {
              'stats': {'totalTracks': FieldValue.increment(chunk.length)},
              'lastSubWrite': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          await batch.commit();
        }
        committedData.addAll(chunk);
      }
    } catch (e) {
      debugPrint('[LibraryProvider] markAlbumTracks rollback — Firestore failed: $e');
      _lastSyncError = 'mark_album_failed';
      if (committedData.isEmpty) {
        _listenedTracks = prevTracks;
        _listenedTrackIds = prevIds;
        _totalTracksCount = prevCount;
      } else {
        // Only rollback uncommitted tracks, preserving tracks committed in earlier batches
        final committedIds = committedData.map((d) => d.trackId).toSet();
        final uncommittedIds = toMark
            .map((t) => t.id)
            .where((id) => !committedIds.contains(id))
            .toSet();

        _listenedTracks.removeWhere((t) => uncommittedIds.contains(t.trackId));
        _listenedTrackIds.removeAll(uncommittedIds);
        _totalTracksCount = _listenedTracks.length;
      }
      _pruneAlbumTrackCounts(forceSave: true);
      notifyListeners();
      unawaited(_storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      ));
    } finally {
      _endSync();
    }
  }

  Future<void> unmarkAlbumTracks(List<String> trackIds) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;

    final toUnmark =
        trackIds.toSet().where((id) => _listenedTrackIds.contains(id)).toList();
    if (toUnmark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update
    _listenedTracks.removeWhere((t) => toUnmark.contains(t.trackId));
    _listenedTrackIds.removeAll(toUnmark);
    _totalTracksCount = _listenedTracks.length;
    _pruneAlbumTrackCounts();
    _lastSyncError = null;
    notifyListeners();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    _startSync();
    final committedUnmarkedIds = <String>[];
    try {
      final customHandler = unmarkAlbumChunkHandlerForTesting;
      final db = customHandler == null ? _firebase.db : null;
      final userDoc = db?.collection('users').doc(uid);
      // Two writes per track (delete + deletion log) + stats, under the 500 cap.
      const batchLimit = 240;

      for (var i = 0; i < toUnmark.length; i += batchLimit) {
        if (i > 0) await Future.delayed(const Duration(milliseconds: 1100));
        final chunk = toUnmark.sublist(
            i, i + batchLimit > toUnmark.length ? toUnmark.length : i + batchLimit);

        if (customHandler != null) {
          await customHandler(chunk, uid);
        } else if (db != null && userDoc != null) {
          final batch = db.batch();
          for (final id in chunk) {
            batch.delete(userDoc.collection('listenedTracks').doc(id));
            batch.set(userDoc.collection('listenedDeletions').doc(id), {
              'deletedAt': FieldValue.serverTimestamp(),
            });
          }
          batch.set(
            userDoc,
            {
              'stats': {'totalTracks': FieldValue.increment(-chunk.length)},
              'lastSubWrite': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          await batch.commit();
        }
        committedUnmarkedIds.addAll(chunk);
      }
    } catch (e) {
      debugPrint('[LibraryProvider] unmarkAlbumTracks rollback — Firestore failed: $e');
      _lastSyncError = 'unmark_album_failed';
      if (committedUnmarkedIds.isEmpty) {
        _listenedTracks = prevTracks;
        _listenedTrackIds = prevIds;
        _totalTracksCount = prevCount;
      } else {
        // Partial delete: only restore the tracks that failed to be deleted from Firestore
        final committedSet = committedUnmarkedIds.toSet();
        final failedToDeleteIds =
            toUnmark.where((id) => !committedSet.contains(id)).toSet();

        final tracksToRestore = prevTracks
            .where((t) => failedToDeleteIds.contains(t.trackId))
            .toList();

        _listenedTracks.addAll(tracksToRestore);
        _listenedTrackIds.addAll(failedToDeleteIds);
        _totalTracksCount = _listenedTracks.length;
      }
      _pruneAlbumTrackCounts(forceSave: true);
      notifyListeners();
      unawaited(_storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      ));
    } finally {
      _endSync();
    }
  }

  void _startSync() {
    _syncCount++;
    _syncing = true;
    notifyListeners();
  }

  void _endSync() {
    _syncCount--;
    if (_syncCount <= 0) {
      _syncCount = 0;
      _syncing = false;
      notifyListeners();
    }
  }

  // --- Top Artists calculation (like web) ---

  List<TopArtistEntry> getTopArtists({int limit = 5}) {
    final Map<String, int> savedCounts = {};
    for (final t in _listenedTracks) {
      final name = t.artistName;
      if (name.isNotEmpty) {
        savedCounts[name] = (savedCounts[name] ?? 0) + 1;
      }
    }

    final allArtists = <String>{...savedCounts.keys, ..._artistVisits.keys};
    final entries = <TopArtistEntry>[];

    for (final name in allArtists) {
      final saved = savedCounts[name] ?? 0;
      final visits = _artistVisits[name] ?? 0;
      final score = (saved * 2) + visits;
      entries.add(TopArtistEntry(
        name: name,
        score: score,
        savedCount: saved,
        visits: visits,
      ));
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries.take(limit).toList();
  }

  // --- Artist visits ---

  Future<void> trackArtistVisit(String artistName) async {
    _artistVisits[artistName] = (_artistVisits[artistName] ?? 0) + 1;
    notifyListeners();
    await _storage.saveArtistVisits(_artistVisits);
  }

  // --- Favorites (local, same as before) ---

  bool isFavoriteTrack(String trackId) {
    return _favoriteTracks.any((t) => t.id == trackId);
  }

  Future<void> toggleFavoriteTrack(Track track) async {
    final index = _favoriteTracks.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _favoriteTracks.removeAt(index);
    } else {
      _favoriteTracks.insert(0, track);
    }
    notifyListeners();
    await _storage.saveFavoriteTracks(_favoriteTracks);
  }

  Future<void> addRecentTrack(Track track) async {
    _recentTracks.removeWhere((t) => t.id == track.id);
    _recentTracks.insert(0, track);
    if (_recentTracks.length > 50) {
      _recentTracks = _recentTracks.sublist(0, 50);
    }
    notifyListeners();
    await _storage.saveRecentTracks(_recentTracks);
  }

  bool isFavoriteArtist(String artistId) {
    return _favoriteArtists.any((a) => a.id == artistId);
  }

  Future<void> toggleFavoriteArtist(Artist artist) async {
    final index = _favoriteArtists.indexWhere((a) => a.id == artist.id);
    if (index >= 0) {
      _favoriteArtists.removeAt(index);
    } else {
      _favoriteArtists.insert(0, artist);
    }
    notifyListeners();
    await _storage.saveFavoriteArtists(_favoriteArtists);
  }

  // --- Followed artists (Firestore-synced) ---

  Future<void> followArtist(Artist artist) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (_followedArtistIds.contains(artist.id)) return;

    final prevArtists = List<Artist>.from(_followedArtists);
    final prevIds = Set<String>.from(_followedArtistIds);

    _followedArtists.add(artist);
    _followedArtistIds.add(artist.id);
    notifyListeners();

    unawaited(_storage.saveCachedFollowedArtists(
      uid,
      _followedArtists.map((a) => a.toJson()).toList(),
    ));

    _startSync();
    try {
      final db = _firebase.db;
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(uid).collection('followedArtists').doc(artist.id),
        artist.toJson(),
      );
      batch.set(db.collection('users').doc(uid),
          {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('[LibraryProvider] followArtist rollback: $e');
      _followedArtists = prevArtists;
      _followedArtistIds = prevIds;
      notifyListeners();
      unawaited(_storage.saveCachedFollowedArtists(
        uid,
        _followedArtists.map((a) => a.toJson()).toList(),
      ));
    } finally {
      _endSync();
    }
  }

  Future<void> unfollowArtist(String artistId) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (!_followedArtistIds.contains(artistId)) return;

    final prevArtists = List<Artist>.from(_followedArtists);
    final prevIds = Set<String>.from(_followedArtistIds);

    _followedArtists.removeWhere((a) => a.id == artistId);
    _followedArtistIds.remove(artistId);
    notifyListeners();

    unawaited(_storage.saveCachedFollowedArtists(
      uid,
      _followedArtists.map((a) => a.toJson()).toList(),
    ));

    _startSync();
    try {
      final db = _firebase.db;
      final batch = db.batch();
      batch.delete(
        db.collection('users').doc(uid).collection('followedArtists').doc(artistId),
      );
      batch.set(db.collection('users').doc(uid),
          {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('[LibraryProvider] unfollowArtist rollback: $e');
      _followedArtists = prevArtists;
      _followedArtistIds = prevIds;
      notifyListeners();
      unawaited(_storage.saveCachedFollowedArtists(
        uid,
        _followedArtists.map((a) => a.toJson()).toList(),
      ));
    } finally {
      _endSync();
    }
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
    _followedArtistsSubscription?.cancel();
    super.dispose();
  }
}
