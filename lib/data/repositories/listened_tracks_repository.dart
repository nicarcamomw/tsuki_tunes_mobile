import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/track.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';
import 'album_completion_index.dart';

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

  factory ListenedTrackData.fromTrack(Track track) => ListenedTrackData(
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

/// The tracks the user marked as listened, synced with
/// `users/{uid}/listenedTracks` in Firestore and cached locally.
///
/// Marks and unmarks apply at once and are rolled back if Firestore rejects
/// them. The local cache is only saved once Firestore confirmed, so a write
/// that never lands can't leave a phantom track behind.
class ListenedTracksRepository {
  final FirebaseService _firebase;
  final StorageService _storage;
  final AlbumCompletionIndex _albums;
  final VoidCallback _onChanged;

  /// Runs a Firestore write while the library shows it is syncing.
  final Future<void> Function(Future<void> Function() write) _tracked;

  ListenedTracksRepository({
    required FirebaseService firebase,
    required StorageService storage,
    required AlbumCompletionIndex albums,
    required VoidCallback onChanged,
    required Future<void> Function(Future<void> Function() write) tracked,
  })  : _firebase = firebase,
        _storage = storage,
        _albums = albums,
        _onChanged = onChanged,
        _tracked = tracked;

  List<ListenedTrackData> _tracks = [];
  Set<String> _ids = {};
  bool _loaded = false;

  /// True when in-memory state has changes not yet confirmed by Firestore.
  /// The delta listener clears this and saves the cache once the server
  /// confirms (hasPendingWrites == false).
  bool _cacheDirty = false;

  /// Last error from a mark/unmark Firestore write, cleared on success.
  /// The UI can watch this to show a snackbar when a save fails.
  String? _lastSyncError;

  StreamSubscription? _tracksSubscription;
  StreamSubscription? _deletionsSubscription;

  // Distinct artists, rebuilt lazily after a change (see [invalidate]).
  bool _dirty = true;
  int _uniqueArtistsCount = 0;

  static const Duration _fullSyncInterval = Duration(hours: 4);
  static const Duration _deletionLogRetention = Duration(days: 7);

  // Test hook, reached through LibraryRepositoryImpl.
  Future<void> Function(List<ListenedTrackData> chunk, String uid)?
      markChunkHandlerForTesting;

  // Test hook, reached through LibraryRepositoryImpl.
  Future<void> Function(List<String> chunkIds, String uid)?
      unmarkChunkHandlerForTesting;

  // Read-only views, not copies: these are read on every rebuild and can hold
  // thousands of tracks. The same view is handed out until the tracks change,
  // so screens can skip work with identical(); every change replaces it.
  List<ListenedTrackData>? _tracksView;
  List<ListenedTrackData> get tracks =>
      _tracksView ??= UnmodifiableListView(_tracks);
  Set<String> get ids => UnmodifiableSetView(_ids);
  int get count => _ids.length;
  bool get loaded => _loaded;
  String? get lastSyncError => _lastSyncError;
  bool contains(String trackId) => _ids.contains(trackId);

  /// The tracks changed: a new [tracks] view and derived counts on next read.
  void invalidate() {
    _dirty = true;
    _tracksView = null;
  }

  /// Every change to the tracks (or the last error) ends here.
  void _changed() {
    invalidate();
    _onChanged();
  }

  int get uniqueArtistsCount {
    if (_dirty) {
      _uniqueArtistsCount = {
        for (final t in _tracks)
          if (t.artistName.isNotEmpty) t.artistName,
      }.length;
      _dirty = false;
    }
    return _uniqueArtistsCount;
  }

  /// Restores the cache, fetches everything when the last full sync is old,
  /// and listens for changes made elsewhere. Returns false when the user
  /// changed meanwhile ([isCurrent] went false), so the caller stops too.
  Future<bool> connect(
    String uid,
    DocumentReference<Map<String, dynamic>> userDoc,
    bool Function() isCurrent,
  ) async {
    unawaited(_tracksSubscription?.cancel());
    unawaited(_deletionsSubscription?.cancel());

    final tracksCol = userDoc.collection('listenedTracks');

    // 1. Instant local cache restore (0ms cold start — tracks never disappear)
    try {
      final cached = await _storage.getCachedListenedTracks(uid);
      if (cached.isNotEmpty && isCurrent()) {
        _tracks = cached.map((e) => ListenedTrackData.fromJson(e)).toList();
        _ids = _tracks.map((t) => t.trackId).toSet();
        _loaded = true;
        _albums.prune();
        _changed();
      }
    } catch (e) {
      debugPrint('[LibraryRepositoryImpl] Error restoring cached tracks: $e');
    }

    // 2. Full fetch only when there is no cache or the last full sync is
    //    older than a day. Otherwise the cache plus the delta listeners below
    //    are enough, so a cold start costs a handful of reads instead of one
    //    per listened track. The daily full fetch also picks up deletions
    //    made by clients that don't write the deletion log (the web app).
    final lastFullSync = await _storage.getLastListenedFullSync(uid);
    if (!isCurrent()) return false;
    final now = DateTime.now();
    final needsFullSync = _tracks.isEmpty ||
        lastFullSync == null ||
        now.difference(lastFullSync) > _fullSyncInterval;
    DateTime deletionsSince =
        (lastFullSync ?? now).subtract(const Duration(minutes: 5));

    if (needsFullSync) {
      try {
        final fetchStartedAt = DateTime.now();
        final snapshot =
            await tracksCol.orderBy('listenedAt', descending: true).get();
        if (!isCurrent()) return false;

        _tracks = snapshot.docs
            .map((doc) =>
                ListenedTrackData.fromFirestore(doc.data(), docId: doc.id))
            .toList();
        _ids = _tracks.map((t) => t.trackId).toSet();
        _loaded = true;
        _changed();

        unawaited(_storage.saveCachedListenedTracks(
          uid,
          _tracks.map((t) => t.toJson()).toList(),
        ));
        unawaited(_storage.saveLastListenedFullSync(uid, fetchStartedAt));
        deletionsSince = fetchStartedAt.subtract(const Duration(minutes: 5));
        _albums.prune();
        _reconcileServerStats(userDoc, _tracks.length);
        _pruneDeletionLog(userDoc);
      } catch (e) {
        debugPrint('[LibraryRepositoryImpl] Initial Firestore fetch error: $e');
      }
    }

    // 3. Delta listener — only docs newer than the latest known timestamp.
    //    The margin absorbs device clock skew in optimistic local entries.
    DateTime? deltaBoundary;
    for (final t in _tracks) {
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
      if (!isCurrent()) return;

      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;

        final data =
            ListenedTrackData.fromFirestore(docData, docId: change.doc.id);

        if (change.type == DocumentChangeType.removed) {
          if (_ids.remove(data.trackId)) {
            _tracks.removeWhere((t) => t.trackId == data.trackId);
            changed = true;
          }
        } else {
          final idx = _tracks.indexWhere((t) => t.trackId == data.trackId);
          if (idx != -1) {
            _tracks[idx] = data;
          } else {
            _tracks.insert(0, data);
            _ids.add(data.trackId);
          }
          changed = true;
        }
      }

      if (changed) {
        _albums.prune();
        _changed();
        _cacheDirty = true;
      }

      // Only persist to SharedPreferences cache once the server has
      // confirmed all pending writes. This prevents phantom tracks from
      // being cached before they actually reach Firestore. When
      // hasPendingWrites transitions from true to false the listener
      // fires again, so the save is never lost.
      if (!snapshot.metadata.hasPendingWrites && _cacheDirty) {
        _cacheDirty = false;
        _saveCache(uid);
      }
    }, onError: (e) {
      debugPrint('[LibraryRepositoryImpl] Firestore delta sync error: $e');
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
      if (!isCurrent()) return;
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
      if (changed) {
        _albums.prune();
        _changed();
        _saveCache(uid);
      }
    }, onError: (e) {
      debugPrint('[LibraryRepositoryImpl] Firestore deletions sync error: $e');
    });
    return true;
  }

  void disconnect() {
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
    _tracksSubscription = null;
    _tracks = [];
    _ids = {};
    _loaded = false;
    _cacheDirty = false;
    _lastSyncError = null;
    invalidate();
  }

  /// Whether listening already started for [uid]'s tracks.
  bool get isListening => _tracksSubscription != null;

  Future<void> _saveCache(String uid) => _storage.saveCachedListenedTracks(
        uid,
        _tracks.map((t) => t.toJson()).toList(),
      );

  /// Applies an unmark made on another device. A track re-marked after the
  /// deletion (newer listenedAt) is kept. Returns whether anything changed.
  bool applyRemoteDeletion(String trackId, DateTime deletedAt) {
    final idx = _tracks.indexWhere((t) => t.trackId == trackId);
    if (idx == -1) return false;
    final listenedAt = _tracks[idx].listenedAt;
    if (listenedAt != null && listenedAt.isAfter(deletedAt)) return false;
    _tracks.removeAt(idx);
    _ids.remove(trackId);
    invalidate();
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
      debugPrint('[LibraryRepositoryImpl] stats reconcile failed: $e');
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
      // The rules only accept subcollection writes stamped with the time.
      batch.set(userDoc, {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await SubWriteQueue.instance.run(batch.commit);
    }).catchError((Object e) {
      debugPrint('[LibraryRepositoryImpl] deletion log prune failed: $e');
    });
  }

  // Test hook, reached through LibraryRepositoryImpl.
  void setLoadedForTesting(bool loaded) => _loaded = loaded;

  // Test hook, reached through LibraryRepositoryImpl.
  void setTracksForTesting(List<ListenedTrackData> tracks) {
    _tracks = List.from(tracks);
    _ids = tracks.map((t) => t.trackId).toSet();
    _loaded = true;
  }

  // --- Writes ---

  /// Puts the snapshot taken before an optimistic change back after
  /// Firestore rejected it, and caches the restored state.
  void _rollback(String uid, List<ListenedTrackData> prevTracks,
      Set<String> prevIds, String error) {
    _tracks = prevTracks;
    _ids = prevIds;
    _lastSyncError = error;
    _changed();
    unawaited(_saveCache(uid));
  }

  Future<void> mark(String uid, Track track) async {
    if (_ids.contains(track.id)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_tracks);
    final prevIds = Set<String>.from(_ids);

    // Optimistic update — UI reflects the mark immediately.
    final data = ListenedTrackData.fromTrack(track);
    _tracks.add(data);
    _ids.add(track.id);
    if (track.albumId.isNotEmpty && _albums.hasTrackCount(track.albumId)) {
      _albums.prune(forceSave: true);
    }
    _lastSyncError = null;
    _changed();

    // NOTE: cache is NOT saved here — it is saved by the delta listener
    // only after Firestore confirms the write, preventing phantom tracks
    // that disappear on the next full sync.

    await _tracked(() async {
      try {
        await _commitMarkBatch(uid, track.id, data);
      } catch (e) {
        // Retry once after a short delay (handles rate-limit / transient errors)
        try {
          await Future.delayed(const Duration(milliseconds: 1500));
          await _commitMarkBatch(uid, track.id, data);
        } catch (retryError) {
          debugPrint('[LibraryRepositoryImpl] markTrack rollback — Firestore failed after retry: $retryError');
          _rollback(uid, prevTracks, prevIds, 'mark_failed');
        }
      }
    });
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
    await SubWriteQueue.instance.run(batch.commit);
    _lastSyncError = null;
  }

  Future<void> unmark(String uid, String trackId) async {
    if (!_ids.contains(trackId)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_tracks);
    final prevIds = Set<String>.from(_ids);

    // Optimistic update
    _tracks.removeWhere((t) => t.trackId == trackId);
    _ids.remove(trackId);
    _albums.prune();
    _lastSyncError = null;
    _changed();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    await _tracked(() async {
      try {
        await _commitUnmarkBatch(uid, trackId);
      } catch (e) {
        // Retry once after a short delay
        try {
          await Future.delayed(const Duration(milliseconds: 1500));
          await _commitUnmarkBatch(uid, trackId);
        } catch (retryError) {
          debugPrint('[LibraryRepositoryImpl] unmarkTrack rollback — Firestore failed after retry: $retryError');
          _rollback(uid, prevTracks, prevIds, 'unmark_failed');
        }
      }
    });
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
    await SubWriteQueue.instance.run(batch.commit);
    _lastSyncError = null;
  }

  /// Marks [tracks] not listened yet, in Firestore batches; a failed batch
  /// rolls back only the tracks it carried.
  Future<void> markAll(String uid, List<Track> tracks) async {
    final seen = <String>{};
    final toMark = <Track>[];
    for (final t in tracks) {
      if (!_ids.contains(t.id) && seen.add(t.id)) {
        toMark.add(t);
      }
    }
    if (toMark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_tracks);
    final prevIds = Set<String>.from(_ids);

    // Optimistic update
    final newData = toMark.map(ListenedTrackData.fromTrack).toList();
    _tracks.addAll(newData);
    _ids.addAll(toMark.map((t) => t.id));
    _albums.prune(forceSave: true);
    _lastSyncError = null;
    _changed();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    await _tracked(() async {
      final committedData = <ListenedTrackData>[];
      try {
        final customHandler = markChunkHandlerForTesting;
        final db = customHandler == null ? _firebase.db : null;
        final userDoc = db?.collection('users').doc(uid);
        const batchLimit = 450;

        for (var i = 0; i < newData.length; i += batchLimit) {
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
            await SubWriteQueue.instance.run(batch.commit);
          }
          committedData.addAll(chunk);
        }
      } catch (e) {
        debugPrint('[LibraryRepositoryImpl] markAlbumTracks rollback — Firestore failed: $e');
        _lastSyncError = 'mark_album_failed';
        if (committedData.isEmpty) {
          _tracks = prevTracks;
          _ids = prevIds;
        } else {
          // Only rollback uncommitted tracks, preserving tracks committed in earlier batches
          final committedIds = committedData.map((d) => d.trackId).toSet();
          final uncommittedIds = toMark
              .map((t) => t.id)
              .where((id) => !committedIds.contains(id))
              .toSet();

          _tracks.removeWhere((t) => uncommittedIds.contains(t.trackId));
          _ids.removeAll(uncommittedIds);
        }
        _albums.prune(forceSave: true);
        _changed();
        unawaited(_saveCache(uid));
      }
    });
  }

  /// Unmarks the listened ones among [trackIds], in Firestore batches; a
  /// failed batch restores only the tracks it carried.
  Future<void> unmarkAll(String uid, List<String> trackIds) async {
    final toUnmark = trackIds.toSet().where((id) => _ids.contains(id)).toList();
    if (toUnmark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_tracks);
    final prevIds = Set<String>.from(_ids);

    // Optimistic update
    _tracks.removeWhere((t) => toUnmark.contains(t.trackId));
    _ids.removeAll(toUnmark);
    _albums.prune();
    _lastSyncError = null;
    _changed();

    // NOTE: cache is NOT saved here — delta listener persists after confirm.

    await _tracked(() async {
      final committedUnmarkedIds = <String>[];
      try {
        final customHandler = unmarkChunkHandlerForTesting;
        final db = customHandler == null ? _firebase.db : null;
        final userDoc = db?.collection('users').doc(uid);
        // Two writes per track (delete + deletion log) + stats, under the 500 cap.
        const batchLimit = 240;

        for (var i = 0; i < toUnmark.length; i += batchLimit) {
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
            await SubWriteQueue.instance.run(batch.commit);
          }
          committedUnmarkedIds.addAll(chunk);
        }
      } catch (e) {
        debugPrint('[LibraryRepositoryImpl] unmarkAlbumTracks rollback — Firestore failed: $e');
        _lastSyncError = 'unmark_album_failed';
        if (committedUnmarkedIds.isEmpty) {
          _tracks = prevTracks;
          _ids = prevIds;
        } else {
          // Partial delete: only restore the tracks that failed to be deleted from Firestore
          final committedSet = committedUnmarkedIds.toSet();
          final failedToDeleteIds =
              toUnmark.where((id) => !committedSet.contains(id)).toSet();

          final tracksToRestore = prevTracks
              .where((t) => failedToDeleteIds.contains(t.trackId))
              .toList();

          _tracks.addAll(tracksToRestore);
          _ids.addAll(failedToDeleteIds);
        }
        _albums.prune(forceSave: true);
        _changed();
        unawaited(_saveCache(uid));
      }
    });
  }

  void dispose() {
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
  }
}
