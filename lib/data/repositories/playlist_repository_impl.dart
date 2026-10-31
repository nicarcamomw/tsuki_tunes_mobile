import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';
import '../local/app_database.dart' show AppDatabase;
import '../local/library_store.dart';
import '../mappers/playlist_firestore.dart';
import '../sync/firestore_sync.dart';
import '../sync/outbox.dart';

/// The account's playlists, offline-first. Every change is an operation
/// (create, rename, delete, a track change) applied here at once and saved
/// with its outbox entry in one transaction; the outbox sends it, retrying
/// until it lands. What shows is the server's copy with the operations
/// still pending replayed on top, so a snapshot from Firestore can't undo
/// them, and a refused one simply drops out. Guests keep their playlists on
/// the phone only.
class PlaylistRepositoryImpl extends ChangeNotifier implements PlaylistRepository {
  final StorageService _storage;
  final FirebaseService _firebase;
  final LibraryStore _store;
  final Outbox _outbox;

  static const createKind = 'playlist.create';
  static const renameKind = 'playlist.rename';
  static const deleteKind = 'playlist.delete';
  static const tracksKind = 'playlist.tracks';
  static const _kinds = {createKind, renameKind, deleteKind, tracksKind};

  /// [store] and [outbox] hold the playlists and the writes on their way to
  /// the server; get_it passes the app's database. Without them (a test) an
  /// in-memory database stands in.
  factory PlaylistRepositoryImpl({
    FirebaseService? firebase,
    StorageService? storage,
    LibraryStore? store,
    Outbox? outbox,
  }) {
    final db = (store == null || outbox == null) ? AppDatabase(NativeDatabase.memory()) : null;
    return PlaylistRepositoryImpl._(
      firebase ?? FirebaseService(),
      storage ?? StorageService(),
      store ?? LibraryStore(db!),
      outbox ?? Outbox(db!),
    );
  }

  PlaylistRepositoryImpl._(this._firebase, this._storage, this._store, this._outbox) {
    for (final kind in _kinds) {
      _outbox.register(kind, _send, onRefused: (entry, _) => unawaited(_refresh(entry.uid)));
    }
  }

  /// The server's copy (newest change first), and what shows: it with the
  /// pending operations replayed on top.
  List<Playlist> _server = [];
  List<Playlist> _playlists = [];
  bool _syncing = false;
  int _syncCount = 0;
  String? _currentUid;
  bool _isGuest = false;
  final List<DateTime> _writeTimestamps = [];
  static const _maxWritesPerMinute = 30;
  StreamSubscription? _playlistsSubscription;

  // Test hook: stands in for the Firestore write of an operation.
  @visibleForTesting
  Future<void> Function(OutboxEntry entry)? sendHandlerForTesting;

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

  bool get _syncs {
    final uid = _currentUid;
    return uid != null && !_isGuest && _canSyncToFirestore(uid);
  }

  /// The saved playlists (the old SharedPreferences copy moves in first).
  Future<List<Playlist>> _loadSaved(String uid) async {
    var saved = await _store.loadPlaylists(uid);
    if (saved.isEmpty) {
      saved = await _storage.getCachedPlaylists(uid);
      if (saved.isNotEmpty) await _store.savePlaylists(uid, saved);
    }
    return _unique(saved.map(Playlist.fromJson));
  }

  Future<void> initLocalOnly(String uid) async {
    _currentUid = uid;
    _isGuest = true;
    try {
      final saved = await _loadSaved(uid);
      if (saved.isNotEmpty && _currentUid == uid) {
        _playlists = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Playlists] opening local playlists failed: $e');
    }
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _playlistsSubscription != null) return;
    _currentUid = uid;
    _isGuest = false;
    unawaited(_playlistsSubscription?.cancel());

    final playlistsCol = _firebase.db.collection('users').doc(uid).collection('playlists');

    // 1. The saved copy, at once. It already holds the pending changes;
    //    replaying them on it again is harmless (every operation is
    //    idempotent).
    try {
      final saved = await _loadSaved(uid);
      if (saved.isNotEmpty && _currentUid == uid) {
        _server = saved;
        await _refresh(uid);
      }
    } catch (e) {
      debugPrint('[Playlists] opening saved playlists failed: $e');
    }

    // 2. Whatever didn't reach the server last time goes now.
    _outbox.kick(uid);

    // 3. The server's copy.
    try {
      final snapshot = await playlistsCol.orderBy('updatedAt', descending: true).get();
      if (_currentUid != uid) return;
      _server = _unique(snapshot.docs.map((d) => playlistFromFirestore(d.data(), docId: d.id)));
      await _refresh(uid);
    } catch (e) {
      debugPrint('[Playlists] fetch failed: $e');
    }

    // 4. Changes made elsewhere. A doc with this device's writes still
    //    pending waits for the server's version: the pending operation
    //    already shows.
    _playlistsSubscription =
        playlistsCol.orderBy('updatedAt', descending: true).snapshots().listen((snapshot) async {
      if (_currentUid != uid) return;
      var changed = false;
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) continue;
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          final before = _server.length;
          _server = [for (final p in _server) if (p.id != id) p];
          changed |= _server.length != before;
          continue;
        }
        final data = change.doc.data();
        if (data == null) continue;
        final playlist = playlistFromFirestore(data, docId: id);
        final idx = _server.indexWhere((p) => p.id == id);
        _server = idx == -1 ? [playlist, ..._server] : ([..._server]..[idx] = playlist);
        changed = true;
      }
      if (changed) await _refresh(uid);
    }, onError: (e) {
      debugPrint('[Playlists] listener error: $e');
    });
  }

  /// Uploads the playlists a guest created on this device into the account
  /// that just signed in (through the outbox, so offline is fine), then
  /// clears the guest copy.
  Future<void> importGuestPlaylists(String guestUid) async {
    final uid = _currentUid;
    if (uid == null || !_syncs) return;
    try {
      final guest = (await _loadSaved(guestUid))
          .where((p) => p.tracks.isNotEmpty || p.name.isNotEmpty)
          .toList();
      if (guest.isEmpty) return;
      final col = _firebase.db.collection('users').doc(uid).collection('playlists');
      final imported = [for (final p in guest) p.copyWith(id: col.doc().id)];
      for (final p in imported) {
        _playlists = _applyOp(_playlists, createKind, p.id, {'playlist': p.toJson()});
      }
      notifyListeners();
      await _store.savePlaylists(uid, _json(_playlists), alsoInTransaction: () async {
        for (final p in imported) {
          await _outbox.enqueue(uid, createKind, p.id, {'playlist': p.toJson()});
        }
      });
      _outbox.kick(uid);
      await _store.clearPlaylists(guestUid);
      await _storage.clearCachedPlaylists(guestUid);
      debugPrint('[Playlists] imported ${imported.length} guest playlists');
    } catch (e) {
      debugPrint('[Playlists] guest import failed: $e');
    }
  }

  void disconnectFirestore() {
    _currentUid = null;
    _isGuest = false;
    _playlistsSubscription?.cancel();
    _playlistsSubscription = null;
    _server = [];
    _playlists = [];
    notifyListeners();
  }

  static List<Map<String, dynamic>> _json(List<Playlist> list) => [for (final p in list) p.toJson()];

  /// What shows: the server's copy with [uid]'s pending operations replayed.
  Future<void> _refresh(String uid) async {
    final pending = (await _outbox.pending(uid)).where((e) => _kinds.contains(e.kind));
    var shown = _server;
    for (final e in pending) {
      shown = _applyOp(shown, e.kind, e.entityId, e.payload);
    }
    if (_currentUid != uid) return;
    _playlists = _unique(shown);
    notifyListeners();
    await _store.savePlaylists(uid, _json(_playlists));
  }

  /// One operation on a list of playlists: the same code applies a change
  /// here at once and replays the pending ones over the server's copy.
  static List<Playlist> _applyOp(List<Playlist> list, String kind, String id, Map<String, dynamic> payload) {
    final at = DateTime.tryParse(payload['at']?.toString() ?? '');
    switch (kind) {
      case createKind:
        if (list.any((p) => p.id == id)) return list;
        return [Playlist.fromJson(Map<String, dynamic>.from(payload['playlist'] as Map)), ...list];
      case deleteKind:
        return [for (final p in list) if (p.id != id) p];
      case renameKind:
        return [
          for (final p in list)
            p.id == id ? p.copyWith(name: payload['name'].toString(), updatedAt: at ?? p.updatedAt) : p,
        ];
      case tracksKind:
        return [
          for (final p in list)
            if (p.id != id)
              p
            else
              p.copyWith(
                tracks: mergePlaylistTracks(
                  [for (final t in p.tracks) t.toJson()],
                  add: payload['add'] == null ? null : Map<String, dynamic>.from(payload['add'] as Map),
                  removeId: payload['removeId']?.toString(),
                  order: (payload['order'] as List?)?.map((e) => e.toString()).toList(),
                ).map(Track.fromJson).toList(),
                updatedAt: at ?? p.updatedAt,
              ),
        ];
    }
    return list;
  }

  /// Applies an operation here at once and saves it; for a signed-in
  /// account the outbox entry goes in the same transaction and is sent.
  Future<void> _change(String uid, String kind, String id, Map<String, dynamic> payload) async {
    _playlists = _applyOp(_playlists, kind, id, payload);
    notifyListeners();
    if (!_syncs) {
      await _store.savePlaylists(uid, _json(_playlists));
      return;
    }
    await _store.savePlaylists(uid, _json(_playlists),
        alsoInTransaction: () => _outbox.enqueue(uid, kind, id, payload));
    _outbox.kick(uid);
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
  /// write instead of one per track. Returns at once with the new playlist.
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
    final now = DateTime.now();
    // The id is made here (Firestore makes ids on the device), so the
    // server's copy of this playlist replaces it instead of adding another.
    final id = _syncs
        ? _firebase.db.collection('users').doc(uid).collection('playlists').doc().id
        : 'local_${now.microsecondsSinceEpoch}';
    final seen = <String>{};
    final playlist = Playlist(
      id: id,
      name: cleanName,
      tracks: tracks.where((t) => seen.add(t.id)).take(Playlist.maxTracks).toList(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _change(uid, createKind, id, {'playlist': playlist.toJson()});
    } finally {
      _creating.remove(cleanName);
    }
    return playlist;
  }

  /// Waits until the writes on their way to the server have been sent.
  @visibleForTesting
  Future<void> get pendingCreations {
    final uid = _currentUid;
    return uid == null ? Future.value() : _outbox.idle(uid);
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final uid = _currentUid;
    if (uid == null || newName.trim().isEmpty || _isWriteThrottled()) return;
    if (getPlaylist(playlistId) == null) return;
    await _change(uid, renameKind, playlistId, {
      'name': _cleanName(newName),
      'at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;
    if (getPlaylist(playlistId) == null) return;
    await _change(uid, deleteKind, playlistId, const {});
  }

  @override
  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return false;
    final playlist = getPlaylist(playlistId);
    if (playlist == null || playlist.contains(track.id) || playlist.isFull) return false;
    await _change(uid, tracksKind, playlistId, {
      'add': track.toJson(),
      'at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  @override
  Future<bool> insertTrackAt(String playlistId, Track track, int index) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return false;
    final playlist = getPlaylist(playlistId);
    if (playlist == null || playlist.contains(track.id) || playlist.isFull) return false;
    final order = [for (final t in playlist.tracks) t.id]..insert(index.clamp(0, playlist.tracks.length), track.id);
    await _change(uid, tracksKind, playlistId, {
      'add': track.toJson(),
      'order': order,
      'at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;
    final playlist = getPlaylist(playlistId);
    if (playlist == null || !playlist.contains(trackId)) return;
    await _change(uid, tracksKind, playlistId, {
      'removeId': trackId,
      'at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex) async {
    final uid = _currentUid;
    if (uid == null || _isWriteThrottled()) return;
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return;
    final ids = [for (final t in playlist.tracks) t.id];
    if (oldIndex < 0 || oldIndex >= ids.length || newIndex < 0 || newIndex >= ids.length) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    await _change(uid, tracksKind, playlistId, {
      'order': ids,
      'at': DateTime.now().toIso8601String(),
    });
  }

  /// Outbox: one operation to Firestore. Each one is idempotent: a create
  /// only writes a playlist the server doesn't have, and track changes are
  /// merged into the server's copy inside a transaction, so edits made on
  /// another device meanwhile are kept. Transactions need the server: offline
  /// it fails, and the outbox retries it once back.
  Future<void> _send(OutboxEntry entry) async {
    _startSync();
    try {
      final testHandler = sendHandlerForTesting;
      if (testHandler != null) return await testHandler(entry);
      await sendToFirestore(() => SubWriteQueue.instance.run(() async {
            final db = _firebase.db;
            final userDoc = db.collection('users').doc(entry.uid);
            final docRef = userDoc.collection('playlists').doc(entry.entityId);
            final stamp = {'lastSubWrite': FieldValue.serverTimestamp()};
            final payload = entry.payload;
            switch (entry.kind) {
              case createKind:
                await db.runTransaction((tx) async {
                  if ((await tx.get(docRef)).exists) return;
                  final playlist = Playlist.fromJson(Map<String, dynamic>.from(payload['playlist'] as Map));
                  tx.set(docRef, playlist.toFirestore());
                  tx.set(userDoc, stamp, SetOptions(merge: true));
                });
              case renameKind:
                final batch = db.batch()
                  ..update(docRef, {'name': payload['name'], 'updatedAt': FieldValue.serverTimestamp()})
                  ..set(userDoc, stamp, SetOptions(merge: true));
                await batch.commit();
              case deleteKind:
                final batch = db.batch()
                  ..delete(docRef)
                  ..set(userDoc, stamp, SetOptions(merge: true));
                await batch.commit();
              case tracksKind:
                await db.runTransaction((tx) async {
                  final snap = await tx.get(docRef);
                  final raw = snap.data()?['tracks'];
                  final server = raw is List
                      ? raw.map((t) => Map<String, dynamic>.from(t as Map)).toList()
                      : <Map<String, dynamic>>[];
                  tx.update(docRef, {
                    'tracks': mergePlaylistTracks(
                      server,
                      add: payload['add'] == null ? null : Map<String, dynamic>.from(payload['add'] as Map),
                      removeId: payload['removeId']?.toString(),
                      order: (payload['order'] as List?)?.map((e) => e.toString()).toList(),
                    ),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  tx.set(userDoc, stamp, SetOptions(merge: true));
                }).timeout(const Duration(seconds: 10));
            }
          }));
    } finally {
      _endSync();
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
}
