import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final FirebaseService _firebase = FirebaseService();

  List<Playlist> _playlists = [];
  bool _syncing = false;
  int _syncCount = 0;
  String? _currentUid;
  bool _isGuest = false;

  StreamSubscription? _playlistsSubscription;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get syncing => _syncing;
  String? get currentUid => _currentUid;

  Playlist? getPlaylist(String id) {
    final idx = _playlists.indexWhere((p) => p.id == id);
    return idx != -1 ? _playlists[idx] : null;
  }

  bool _canSyncToFirestore(String uid) {
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    if (_firebase.currentUser == null) return false;
    return true;
  }

  Future<void> initLocalOnly(String uid) async {
    _currentUid = uid;
    _isGuest = true;
    try {
      final cached = await _storage.getCachedPlaylists(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _playlists = cached.map((e) => Playlist.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PlaylistProvider] Error restoring local playlists: $e');
    }
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _playlistsSubscription != null) return;
    _currentUid = uid;
    _isGuest = false;

    _playlistsSubscription?.cancel();

    final db = _firebase.db;
    final playlistsCol =
        db.collection('users').doc(uid).collection('playlists');

    // Phase 1: Instant local cache restore
    try {
      final cached = await _storage.getCachedPlaylists(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _playlists = cached.map((e) => Playlist.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PlaylistProvider] Error restoring cached playlists: $e');
    }

    // Phase 2: One-time full fetch
    try {
      final snapshot =
          await playlistsCol.orderBy('updatedAt', descending: true).get();
      if (_currentUid != uid) return;

      _playlists = snapshot.docs
          .map((doc) => Playlist.fromFirestore(doc.data(), docId: doc.id))
          .toList();
      notifyListeners();

      _persistCache(uid);
    } catch (e) {
      debugPrint('[PlaylistProvider] Initial Firestore fetch error: $e');
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
            Playlist.fromFirestore(docData, docId: change.doc.id);

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
      debugPrint('[PlaylistProvider] Firestore playlist sync error: $e');
    });
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

  Future<Playlist?> createPlaylist(String name) async {
    final uid = _currentUid;
    if (uid == null || name.trim().isEmpty) return null;

    final now = DateTime.now();
    final tempId = 'local_${now.millisecondsSinceEpoch}';
    final playlist = Playlist(
      id: tempId,
      name: name.trim(),
      tracks: [],
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic
    _playlists.insert(0, playlist);
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final db = _firebase.db;
        final docRef =
            db.collection('users').doc(uid).collection('playlists').doc();
        await docRef.set(playlist.copyWith(id: docRef.id).toFirestore());

        final idx = _playlists.indexWhere((p) => p.id == tempId);
        if (idx != -1) {
          _playlists[idx] = playlist.copyWith(id: docRef.id);
          notifyListeners();
          _persistCache(uid);
        }
        return _playlists.firstWhere((p) => p.id == docRef.id,
            orElse: () => playlist.copyWith(id: docRef.id));
      } catch (e) {
        debugPrint('[PlaylistProvider] createPlaylist rollback: $e');
        _playlists.removeWhere((p) => p.id == tempId);
        notifyListeners();
        _persistCache(uid);
        return null;
      } finally {
        _endSync();
      }
    }

    return playlist;
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final uid = _currentUid;
    if (uid == null || newName.trim().isEmpty) return;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final prev = _playlists[idx];
    final updated =
        prev.copyWith(name: newName.trim(), updatedAt: DateTime.now());

    // Optimistic
    _playlists[idx] = updated;
    notifyListeners();
    _persistCache(uid);

    if (!_isGuest && _canSyncToFirestore(uid)) {
      _startSync();
      try {
        final db = _firebase.db;
        await db
            .collection('users')
            .doc(uid)
            .collection('playlists')
            .doc(playlistId)
            .update({
          'name': newName.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[PlaylistProvider] renamePlaylist rollback: $e');
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

  Future<void> deletePlaylist(String playlistId) async {
    final uid = _currentUid;
    if (uid == null) return;

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
        await db
            .collection('users')
            .doc(uid)
            .collection('playlists')
            .doc(playlistId)
            .delete();
      } catch (e) {
        debugPrint('[PlaylistProvider] deletePlaylist rollback: $e');
        _playlists.insert(idx.clamp(0, _playlists.length), prev);
        notifyListeners();
        _persistCache(uid);
      } finally {
        _endSync();
      }
    }
  }

  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    final uid = _currentUid;
    if (uid == null) return false;

    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return false;

    final playlist = _playlists[idx];
    if (playlist.tracks.any((t) => t.id == track.id)) return false;

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
        final db = _firebase.db;
        await db
            .collection('users')
            .doc(uid)
            .collection('playlists')
            .doc(playlistId)
            .update(updated.toFirestore());
      } catch (e) {
        debugPrint('[PlaylistProvider] addTrackToPlaylist rollback: $e');
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

  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackId) async {
    final uid = _currentUid;
    if (uid == null) return;

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
        final db = _firebase.db;
        await db
            .collection('users')
            .doc(uid)
            .collection('playlists')
            .doc(playlistId)
            .update(updated.toFirestore());
      } catch (e) {
        debugPrint('[PlaylistProvider] removeTrackFromPlaylist rollback: $e');
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

  Future<void> reorderTrack(
      String playlistId, int oldIndex, int newIndex) async {
    final uid = _currentUid;
    if (uid == null) return;

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
        final db = _firebase.db;
        await db
            .collection('users')
            .doc(uid)
            .collection('playlists')
            .doc(playlistId)
            .update(updated.toFirestore());
      } catch (e) {
        debugPrint('[PlaylistProvider] reorderTrack rollback: $e');
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
  void dispose() {
    _playlistsSubscription?.cancel();
    super.dispose();
  }
}
