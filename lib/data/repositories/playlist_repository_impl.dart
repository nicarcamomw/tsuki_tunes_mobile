import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';
import '../mappers/playlist_firestore.dart';

class PlaylistRepositoryImpl extends ChangeNotifier implements PlaylistRepository {
  final StorageService _storage;
  final FirebaseService _firebase;

  PlaylistRepositoryImpl({FirebaseService? firebase, StorageService? storage})
      : _firebase = firebase ?? FirebaseService(),
        _storage = storage ?? StorageService();

  List<Playlist> _playlists = [];
  bool _syncing = false;
  int _syncCount = 0;
  String? _currentUid;
  bool _isGuest = false;
  final List<DateTime> _writeTimestamps = [];
  static const _maxWritesPerMinute = 30;

  StreamSubscription? _playlistsSubscription;
  // Names being created right now: a double tap makes one playlist.
  final Set<String> _creating = {};

  /// One entry per id, keeping the first (newest) one. Older versions of
  /// the app could save the same playlist twice.
  static List<Playlist> _unique(Iterable<Playlist> list) {
    final seen = <String>{};
    return [for (final p in list) if (seen.add(p.id)) p];
  }

  @override
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get syncing => _syncing;
  String? get currentUid => _currentUid;

  Playlist? getPlaylist(String id) {
    final idx = _playlists.indexWhere((p) => p.id == id);
    return idx != -1 ? _playlists[idx] : null;
  }

  /// The database rejects longer names and bigger playlists
  /// (firestore.rules); checking here gives a clear no instead of a silent
  /// rollback.
  static const int maxNameLength = 100;

  static String _cleanName(String name) {
    final trimmed = name.trim();
    return trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed;
  }

  bool _isWriteThrottled() {
    final now = DateTime.now();
    _writeTimestamps.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (_writeTimestamps.length >= _maxWritesPerMinute) return true;
    _writeTimestamps.add(now);
    return false;
  }

  bool _canSyncToFirestore(String uid) {
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    if (!_firebase.isSignedIn) return false;
    return true;
  }

  Future<void> initLocalOnly(String uid) async {
    _currentUid = uid;
    _isGuest = true;
    try {
      final cached = await _storage.getCachedPlaylists(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _playlists = _unique(cached.map((e) => Playlist.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PlaylistRepositoryImpl] Error restoring local playlists: $e');
    }
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _playlistsSubscription != null) return;
    _currentUid = uid;
    _isGuest = false;

    unawaited(_playlistsSubscription?.cancel());

    final db = _firebase.db;
    final playlistsCol =
        db.collection('users').doc(uid).collection('playlists');

    // Phase 1: Instant local cache restore
    try {
      final cached = await _storage.getCachedPlaylists(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _playlists = _unique(cached.map((e) => Playlist.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PlaylistRepositoryImpl] Error restoring cached playlists: $e');
    }

    // Phase 2: One-time full fetch
    try {
      final snapshot =
          await playlistsCol.orderBy('updatedAt', descending: true).get();
      if (_currentUid != uid) return;

      _playlists = _unique(snapshot.docs
          .map((doc) => playlistFromFirestore(doc.data(), docId: doc.id)));
      notifyListeners();

      _persistCache(uid);
    } catch (e) {
      debugPrint('[PlaylistRepositoryImpl] Initial Firestore fetch error: $e');
    }

    // Phase 3: Real-time delta listener
    _playlistsSubscription = playlistsCol
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (_currentUid != uid) return;

      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;

        final playlist =
            playlistFromFirestore(docData, docId: change.doc.id);

        if (change.type == DocumentChangeType.removed) {
          final removed = _playlists.indexWhere((p) => p.id == playlist.id);
          if (removed != -1) {
            _playlists.removeAt(removed);
            changed = true;
          }
        } else {
          final idx = _playlists.indexWhere((p) => p.id == playlist.id);
          if (idx != -1) {
            _playlists[idx] = playlist;
          } else {
            _playlists.insert(0, playlist);
          }
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
        _persistCache(uid);
      }
    }, onError: (e) {
      debugPrint('[PlaylistRepositoryImpl] Firestore playlist sync error: $e');
    });
  }

  /// Uploads the playlists a guest created on this device into the account
  /// that just signed in, then clears the guest copy.
  Future<void> importGuestPlaylists(String guestUid) async {
    final uid = _currentUid;
    if (uid == null || _isGuest || !_canSyncToFirestore(uid)) return;
    try {
      final cached = await _storage.getCachedPlaylists(guestUid);
      final guestPlaylists = cached
          .map((e) => Playlist.fromJson(e))
          .where((p) => p.tracks.isNotEmpty || p.name.isNotEmpty)
          .toList();
      if (guestPlaylists.isEmpty) return;

      final col =
          _firebase.db.collection('users').doc(uid).collection('playlists');
      final batch = _firebase.db.batch();
      for (final p in guestPlaylists) {
        final docRef = col.doc();
        batch.set(docRef, p.copyWith(id: docRef.id).toFirestore());
      }
      // The rules only accept subcollection writes stamped with the time.
      batch.set(_firebase.db.collection('users').doc(uid),
          {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await SubWriteQueue.instance.run(batch.commit);
      await _storage.saveCachedPlaylists(guestUid, []);
      debugPrint('[PlaylistRepositoryImpl] Imported ${guestPlaylists.length} guest playlists');
    } catch (e) {
      debugPrint('[PlaylistRepositoryImpl] Guest playlist import failed: $e');
    }
  }

  void disconnectFirestore() {
    _currentUid = null;
    _isGuest = false;
    _playlistsSubscription?.cancel();
    _playlists = [];
    notifyListeners();
  }

  void _persistCache(String uid) {
    _storage.saveCachedPlaylists(
      uid,
      _playlists.map((p) => p.toJson()).toList(),
    );
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

  // --- CRUD Operations ---

  /// [tracks] are included in the same write, so seeding a playlist costs one
  /// write instead of one per track.
  ///
  /// Returns at once with the new playlist; the upload goes on in the
  /// background (and takes it back out if the server refuses it).
  @override
  Future<Playlist?> createPlaylist(String name, {List<Track> tracks = const []}) async {
    final uid = _currentUid;
    if (uid == null || name.trim().isEmpty) return null;
    final cleanName = _cleanName(name);
    // Same name already on its way (a double tap): don't make another.
    if (!_creating.add(cleanName)) return null;
    if (_isWriteThrottled()) {
      _creating.remove(cleanName);
      return null;
    }
    final (playlist, saved) = _create(uid, cleanName, tracks);
    unawaited(saved.whenComplete(() => _creating.remove(cleanName)));
    return playlist;
  }

  /// Waits until the playlists being created have been uploaded.
  @visibleForTesting
  Future<void> get pendingCreations => Future.wait(_pendingCreations);
  final List<Future<void>> _pendingCreations = [];

  (Playlist, Future<void>) _create(String uid, String name, List<Track> tracks) {
    final now = DateTime.now();
    final synced = !_isGuest && _canSyncToFirestore(uid);
    // The document's id is made here, before writing: the listener then
    // reports this same playlist, which replaces it instead of adding a
    // second copy.
    final docRef = synced
        ? _firebase.db.collection('users').doc(uid).collection('playlists').doc()
        : null;
    final seen = <String>{};
    final playlist = Playlist(
      id: docRef?.id ?? 'local_${now.microsecondsSinceEpoch}',
      name: name,
      tracks: tracks.where((t) => seen.add(t.id)).take(Playlist.maxTracks).toList(),
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic
    _playlists.insert(0, playlist);
    notifyListeners();
    _persistCache(uid);

    if (docRef == null) return (playlist, Future.value());

    _startSync();
    Future<void> upload() async {
      try {
        final db = _firebase.db;
        final batch = db.batch();
        batch.set(docRef, playlist.toFirestore());
        batch.set(db.collection('users').doc(uid),
            {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] createPlaylist rollback: $e');
        _playlists.removeWhere((p) => p.id == playlist.id);
        notifyListeners();
        _persistCache(uid);
      } finally {
        _endSync();
      }
    }

    final saved = upload();
    _pendingCreations.add(saved);
    unawaited(saved.whenComplete(() => _pendingCreations.remove(saved)));
    return (playlist, saved);
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final uid = _currentUid;
    if (uid == null || newName.trim().isEmpty || _isWriteThrottled()) return;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final prev = _playlists[idx];
    final updated =
        prev.copyWith(name: _cleanName(newName), updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final db = _firebase.db;
        final batch = db.batch();
        batch.update(
            db.collection('users').doc(uid).collection('playlists').doc(playlistId),
            {'name': updated.name, 'updatedAt': FieldValue.serverTimestamp()});
        batch.set(db.collection('users').doc(uid),
            {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] renamePlaylist rollback: $e');
        final rollIdx = _playlists.indexWhere((p) => p.id == playlistId);
        if (rollIdx != -1) {
          _playlists[rollIdx] = prev;
          notifyListeners();
          _persistCache(uid);
        }
      } finally {
        _endSync();
      }
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final prev = _playlists[idx];

    // Optimistic
    _playlists.removeAt(idx);
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final db = _firebase.db;
        final batch = db.batch();
        batch.delete(
            db.collection('users').doc(uid).collection('playlists').doc(playlistId));
        batch.set(db.collection('users').doc(uid),
            {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] deletePlaylist rollback: $e');
        _playlists.insert(idx.clamp(0, _playlists.length), prev);
        notifyListeners();
        _persistCache(uid);
      } finally {
        _endSync();
      }
    }
  }

  @override
  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return false;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return false;

    final playlist = _playlists[idx];
    if (playlist.tracks.any((t) => t.id == track.id)) return false;
    if (playlist.isFull) return false;

    final prev = playlist;
    final updatedTracks = [...playlist.tracks, track];
    final updated =
        playlist.copyWith(tracks: updatedTracks, updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        await _commitTracks(uid, updated,
            (server) => mergePlaylistTracks(server, add: track.toJson()));
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] addTrackToPlaylist rollback: $e');
        final rollIdx = _playlists.indexWhere((p) => p.id == playlistId);
        if (rollIdx != -1) {
          _playlists[rollIdx] = prev;
          notifyListeners();
          _persistCache(uid);
        }
        return false;
      } finally {
        _endSync();
      }
    }

    return true;
  }

  /// Puts [track] back at [index] (undoing a removal), in one write.
  @override
  Future<bool> insertTrackAt(String playlistId, Track track, int index) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return false;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return false;

    final prev = _playlists[idx];
    if (prev.tracks.any((t) => t.id == track.id)) return false;
    if (prev.isFull) return false;
    final tracks = List<Track>.from(prev.tracks)
      ..insert(index.clamp(0, prev.tracks.length), track);
    final updated = prev.copyWith(tracks: tracks, updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final order = tracks.map((t) => t.id).toList();
        await _commitTracks(
            uid,
            updated,
            (server) => mergePlaylistTracks(server,
                add: track.toJson(), order: order));
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] insertTrackAt rollback: $e');
        final rollIdx = _playlists.indexWhere((p) => p.id == playlistId);
        if (rollIdx != -1) {
          _playlists[rollIdx] = prev;
          notifyListeners();
          _persistCache(uid);
        }
        return false;
      } finally {
        _endSync();
      }
    }
    return true;
  }

  @override
  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackId) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final prev = _playlists[idx];
    final updatedTracks =
        prev.tracks.where((t) => t.id != trackId).toList();
    final updated =
        prev.copyWith(tracks: updatedTracks, updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        await _commitTracks(uid, updated,
            (server) => mergePlaylistTracks(server, removeId: trackId));
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] removeTrackFromPlaylist rollback: $e');
        final rollIdx = _playlists.indexWhere((p) => p.id == playlistId);
        if (rollIdx != -1) {
          _playlists[rollIdx] = prev;
          notifyListeners();
          _persistCache(uid);
        }
      } finally {
        _endSync();
      }
    }
  }

  @override
  Future<void> reorderTrack(
      String playlistId, int oldIndex, int newIndex) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final prev = _playlists[idx];
    final tracks = List<Track>.from(prev.tracks);

    if (oldIndex < 0 ||
        oldIndex >= tracks.length ||
        newIndex < 0 ||
        newIndex >= tracks.length) {
      return;
    }

    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    final updated =
        prev.copyWith(tracks: tracks, updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final order = updated.tracks.map((t) => t.id).toList();
        await _commitTracks(uid, updated,
            (server) => mergePlaylistTracks(server, order: order));
      } catch (e) {
        debugPrint('[PlaylistRepositoryImpl] reorderTrack rollback: $e');
        final rollIdx = _playlists.indexWhere((p) => p.id == playlistId);
        if (rollIdx != -1) {
          _playlists[rollIdx] = prev;
          notifyListeners();
          _persistCache(uid);
        }
      } finally {
        _endSync();
      }
    }
  }

  /// Applies a track-list change on top of the *server* copy inside a
  /// transaction, so edits made concurrently on another device are kept
  /// instead of overwritten by this device's full list. Transactions need the
  /// server, so offline it falls back to writing the local list (queued by
  /// Firestore until reconnect), which is the previous behaviour.
  Future<void> _commitTracks(
    String uid,
    Playlist local,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> server)
        apply,
  ) =>
      // The transaction and its fallbacks are one turn: only one of them
      // lands, and the next stamped write waits until it has.
      SubWriteQueue.instance.run(() => _commitTracksNow(uid, local, apply));

  Future<void> _commitTracksNow(
    String uid,
    Playlist local,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> server)
        apply,
  ) async {
    final db = _firebase.db;
    final docRef = db
        .collection('users')
        .doc(uid)
        .collection('playlists')
        .doc(local.id);
    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final raw = snap.data()?['tracks'];
        final server = raw is List
            ? raw.map((t) => Map<String, dynamic>.from(t as Map)).toList()
            : <Map<String, dynamic>>[];
        tx.update(docRef, {
          'tracks': apply(server),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(db.collection('users').doc(uid),
            {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }).timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      final batch = db.batch();
      batch.update(docRef, local.toFirestore());
      batch.set(db.collection('users').doc(uid),
          {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await batch.commit();
    } on TimeoutException {
      final batch = db.batch();
      batch.update(docRef, local.toFirestore());
      batch.set(db.collection('users').doc(uid),
          {'lastSubWrite': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await batch.commit();
    }
  }

  /// Merges one change into the server's track list (maps keyed by 'id').
  /// - [add]: appended unless a track with the same id is already there.
  /// - [removeId]: every entry with that id is dropped.
  /// - [order]: ids in the desired order; server tracks missing from it
  ///   (added elsewhere meanwhile) keep their relative order at the end.
  @visibleForTesting
  static List<Map<String, dynamic>> mergePlaylistTracks(
    List<Map<String, dynamic>> server, {
    Map<String, dynamic>? add,
    String? removeId,
    List<String>? order,
  }) {
    var result = List<Map<String, dynamic>>.from(server);
    if (removeId != null) {
      result = result.where((t) => t['id']?.toString() != removeId).toList();
    }
    if (add != null &&
        !result.any((t) => t['id']?.toString() == add['id']?.toString())) {
      result.add(add);
    }
    if (order != null) {
      final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
      final known = result
          .where((t) => rank.containsKey(t['id']?.toString()))
          .toList()
        ..sort((a, b) =>
            rank[a['id']?.toString()]!.compareTo(rank[b['id']?.toString()]!));
      final extra = result
          .where((t) => !rank.containsKey(t['id']?.toString()))
          .toList();
      result = [...known, ...extra];
    }
    return result;
  }

  @override
  void dispose() {
    _playlistsSubscription?.cancel();
    super.dispose();
  }
}
