import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/artist.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';

/// The artists the user follows (release radar alerts), synced with
/// `users/{uid}/followedArtists` in Firestore and cached locally.
/// Follows apply at once and are rolled back if Firestore rejects them.
class FollowedArtistsRepository {
  final FirebaseService _firebase;
  final StorageService _storage;
  final VoidCallback _onChanged;

  /// Runs a Firestore write while the library shows it is syncing.
  final Future<void> Function(Future<void> Function() write) _tracked;

  FollowedArtistsRepository({
    required FirebaseService firebase,
    required StorageService storage,
    required VoidCallback onChanged,
    required Future<void> Function(Future<void> Function() write) tracked,
  })  : _firebase = firebase,
        _storage = storage,
        _onChanged = onChanged,
        _tracked = tracked;

  List<Artist> _artists = [];
  Set<String> _ids = {};
  StreamSubscription? _subscription;

  List<Artist> get artists => UnmodifiableListView(_artists);
  Set<String> get ids => UnmodifiableSetView(_ids);
  bool isFollowed(String artistId) => _ids.contains(artistId);

  /// Stops listening to the previous user's follows.
  void stopListening() => unawaited(_subscription?.cancel());

  /// Restores the cache, fetches the follows and listens for changes made
  /// elsewhere, while [isCurrent] says the user is still the same.
  Future<void> connect(
    String uid,
    DocumentReference<Map<String, dynamic>> userDoc,
    bool Function() isCurrent,
  ) async {
    try {
      final cached = await _storage.getCachedFollowedArtists(uid);
      if (cached.isNotEmpty && isCurrent()) {
        _artists = cached.map((e) => Artist.fromJson(e)).toList();
        _ids = _artists.map((a) => a.id).toSet();
        _onChanged();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] Error restoring cached followed artists: $e');
    }

    final followedCol = userDoc.collection('followedArtists');
    try {
      final snapshot = await followedCol.get();
      if (!isCurrent()) return;
      _artists = snapshot.docs
          .map((doc) => Artist.fromJson(doc.data()))
          .toList();
      _ids = _artists.map((a) => a.id).toSet();
      _onChanged();
      unawaited(_saveCache(uid));
    } catch (e) {
      debugPrint('[LibraryProvider] Followed artists fetch error: $e');
    }

    _subscription = followedCol.snapshots().listen((snapshot) {
      if (!isCurrent()) return;
      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;
        final artist = Artist.fromJson(docData);
        if (change.type == DocumentChangeType.removed) {
          if (_ids.remove(artist.id)) {
            _artists.removeWhere((a) => a.id == artist.id);
            changed = true;
          }
        } else {
          if (!_ids.contains(artist.id)) {
            _artists.add(artist);
            _ids.add(artist.id);
            changed = true;
          }
        }
      }
      if (changed) {
        _onChanged();
        _saveCache(uid);
      }
    }, onError: (e) {
      debugPrint('[LibraryProvider] Followed artists sync error: $e');
    });
  }

  void disconnect() {
    _subscription?.cancel();
    _artists = [];
    _ids = {};
  }

  Future<void> _saveCache(String uid) => _storage.saveCachedFollowedArtists(
        uid,
        _artists.map((a) => a.toJson()).toList(),
      );

  Future<void> follow(String uid, Artist artist) async {
    if (_ids.contains(artist.id)) return;
    final prevArtists = List<Artist>.from(_artists);
    final prevIds = Set<String>.from(_ids);

    _artists.add(artist);
    _ids.add(artist.id);
    await _write(uid, prevArtists, prevIds, (userDoc, batch) {
      batch.set(userDoc.collection('followedArtists').doc(artist.id),
          artist.toJson());
    }, 'followArtist');
  }

  Future<void> unfollow(String uid, String artistId) async {
    if (!_ids.contains(artistId)) return;
    final prevArtists = List<Artist>.from(_artists);
    final prevIds = Set<String>.from(_ids);

    _artists.removeWhere((a) => a.id == artistId);
    _ids.remove(artistId);
    await _write(uid, prevArtists, prevIds, (userDoc, batch) {
      batch.delete(userDoc.collection('followedArtists').doc(artistId));
    }, 'unfollowArtist');
  }

  /// Shows and caches the optimistic change, then commits [addWrites] to
  /// Firestore; on failure puts [prevArtists] back.
  Future<void> _write(
    String uid,
    List<Artist> prevArtists,
    Set<String> prevIds,
    void Function(
            DocumentReference<Map<String, dynamic>> userDoc, WriteBatch batch)
        addWrites,
    String label,
  ) async {
    _onChanged();
    unawaited(_saveCache(uid));

    await _tracked(() async {
      try {
        final db = _firebase.db;
        final userDoc = db.collection('users').doc(uid);
        final batch = db.batch();
        addWrites(userDoc, batch);
        batch.set(userDoc, {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      } catch (e) {
        debugPrint('[LibraryProvider] $label rollback: $e');
        _artists = prevArtists;
        _ids = prevIds;
        _onChanged();
        unawaited(_saveCache(uid));
      }
    });
  }

  void dispose() => _subscription?.cancel();
}
