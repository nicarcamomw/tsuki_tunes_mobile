import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/artist.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';
import '../local/library_store.dart';
import '../sync/firestore_sync.dart';
import '../sync/outbox.dart';

/// The artists the account follows (their new releases reach the radar),
/// offline-first: following or unfollowing saves here at once, with an
/// outbox entry in the same transaction, and the outbox sends it. What
/// shows is the server's list with the changes still on their way up laid
/// on top, so a list arriving from Firestore can't undo them.
class FollowedArtistsRepository {
  final FirebaseService _firebase;
  final StorageService _storage;
  final LibraryStore _store;
  final Outbox _outbox;
  final VoidCallback _onChanged;

  /// Runs a Firestore write while the library shows it is syncing.
  final Future<void> Function(Future<void> Function() write) _tracked;

  static const followKind = 'follow.set';
  static const unfollowKind = 'follow.delete';

  FollowedArtistsRepository({
    required FirebaseService firebase,
    required StorageService storage,
    required LibraryStore store,
    required Outbox outbox,
    required VoidCallback onChanged,
    required Future<void> Function(Future<void> Function() write) tracked,
  })  : _firebase = firebase,
        _storage = storage,
        _store = store,
        _outbox = outbox,
        _onChanged = onChanged,
        _tracked = tracked {
    _outbox
      ..register(followKind, _send, onRefused: _refused)
      ..register(unfollowKind, _send, onRefused: _refused);
  }

  List<Artist> _artists = [];
  Set<String> _ids = {};
  String? _uid;

  // Test hook, reached through LibraryRepositoryImpl: stands in for the
  // Firestore write.
  Future<void> Function(OutboxEntry entry)? sendHandlerForTesting;
  StreamSubscription? _subscription;

  List<Artist> get artists => UnmodifiableListView(_artists);
  Set<String> get ids => UnmodifiableSetView(_ids);
  bool isFollowed(String artistId) => _ids.contains(artistId);

  /// Stops listening to the previous user's follows.
  void stopListening() => unawaited(_subscription?.cancel());

  void _show(List<Artist> artists) {
    _artists = artists;
    _ids = artists.map((a) => a.id).toSet();
    _onChanged();
  }

  /// Opens the saved follows, sends what was pending, then takes the
  /// server's list (with pending changes on top) and listens for changes
  /// made elsewhere, while [isCurrent] says the user is still the same.
  Future<void> connect(
    String uid,
    DocumentReference<Map<String, dynamic>> userDoc,
    bool Function() isCurrent,
  ) async {
    _uid = uid;
    try {
      var saved = await _store.loadFollowed(uid);
      if (saved.isEmpty) {
        // The old SharedPreferences copy moves in.
        saved = await _storage.getCachedFollowedArtists(uid);
        if (saved.isNotEmpty) await _store.saveFollowed(uid, saved);
      }
      if (saved.isNotEmpty && isCurrent()) _show(saved.map(Artist.fromJson).toList());
    } catch (e) {
      debugPrint('[Follows] opening the saved follows failed: $e');
    }
    _outbox.kick(uid);

    final followedCol = userDoc.collection('followedArtists');
    try {
      final snapshot = await followedCol.get();
      if (!isCurrent()) return;
      await _takeServer(uid, snapshot.docs.map((d) => Artist.fromJson(d.data())).toList());
    } catch (e) {
      debugPrint('[Follows] fetch failed: $e');
    }

    _subscription = followedCol.snapshots().listen((snapshot) async {
      if (!isCurrent()) return;
      // Skip this device's own writes not on the server yet.
      if (snapshot.metadata.hasPendingWrites) return;
      await _takeServer(uid, snapshot.docs.map((d) => Artist.fromJson(d.data())).toList());
    }, onError: (e) {
      debugPrint('[Follows] listener error: $e');
    });
  }

  /// [server] with the follows and unfollows still pending laid on top.
  Future<void> _takeServer(String uid, List<Artist> server) async {
    final pending = await _outbox.pending(uid);
    final byId = {for (final a in server) a.id: a};
    final order = [for (final a in _artists) a.id, for (final a in server) a.id];
    for (final e in pending) {
      if (e.kind == followKind) {
        byId[e.entityId] = Artist.fromJson(Map<String, dynamic>.from(e.payload['artist'] as Map));
      } else if (e.kind == unfollowKind) {
        byId.remove(e.entityId);
      }
    }
    if (_uid != uid) return;
    // Known artists keep their place; new ones go at the end.
    final seen = <String>{};
    final merged = [
      for (final id in [...order, ...byId.keys])
        if (byId.containsKey(id) && seen.add(id)) byId[id]!,
    ];
    _show(merged);
    await _store.saveFollowed(uid, [for (final a in merged) a.toJson()]);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _uid = null;
    _artists = [];
    _ids = {};
  }

  Future<void> follow(String uid, Artist artist) async {
    if (_ids.contains(artist.id)) return;
    _uid = uid;
    _show([..._artists, artist]);
    await _store.saveFollowed(
      uid,
      [for (final a in _artists) a.toJson()],
      alsoInTransaction: () => _outbox.enqueue(uid, followKind, artist.id, {'artist': artist.toJson()}),
    );
    _outbox.kick(uid);
  }

  Future<void> unfollow(String uid, String artistId) async {
    if (!_ids.contains(artistId)) return;
    _uid = uid;
    final artist = _artists.firstWhere((a) => a.id == artistId);
    _show([for (final a in _artists) if (a.id != artistId) a]);
    await _store.saveFollowed(
      uid,
      [for (final a in _artists) a.toJson()],
      // The artist rides along so a refused unfollow can bring them back.
      alsoInTransaction: () => _outbox.enqueue(uid, unfollowKind, artistId, {'artist': artist.toJson()}),
    );
    _outbox.kick(uid);
  }

  /// Outbox: one follow or unfollow to Firestore (idempotent: a set or a
  /// delete of the artist's doc).
  Future<void> _send(OutboxEntry entry) => _tracked(() => sendHandlerForTesting?.call(entry) ?? sendToFirestore(() async {
        final db = _firebase.db;
        final userDoc = db.collection('users').doc(entry.uid);
        final doc = userDoc.collection('followedArtists').doc(entry.entityId);
        final batch = db.batch();
        if (entry.kind == followKind) {
          batch.set(doc, Map<String, dynamic>.from(entry.payload['artist'] as Map));
        } else {
          batch.delete(doc);
        }
        batch.set(userDoc, {'lastSubWrite': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      }));

  /// The server refused a follow or unfollow for good: undo it here.
  void _refused(OutboxEntry entry, Object error) {
    if (_uid != entry.uid) return;
    if (entry.kind == followKind) {
      _show([for (final a in _artists) if (a.id != entry.entityId) a]);
    } else if (!_ids.contains(entry.entityId) && entry.payload['artist'] != null) {
      _show([..._artists, Artist.fromJson(Map<String, dynamic>.from(entry.payload['artist'] as Map))]);
    }
    unawaited(_store.saveFollowed(entry.uid, [for (final a in _artists) a.toJson()]));
  }

  void dispose() => _subscription?.cancel();
}
