import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';

import '../../domain/entities/track.dart';
import '../../domain/logic/artist_names.dart';
import '../datasources/firebase_service.dart';
import '../datasources/storage_service.dart';
import '../datasources/sub_write_queue.dart';
import '../local/library_store.dart';
import '../sync/firestore_sync.dart';
import '../sync/outbox.dart';
import 'album_completion_index.dart';
import '../../core/logger.dart';


final _log = Log.named('Listened');

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

  /// Each artist of the song (a collaboration has several). Songs marked
  /// before this was kept only have [artistName], all of them joined by
  /// commas: [hasArtistList] is false and this is a best guess.
  final List<String> artists;
  final bool hasArtistList;

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
    List<String>? artists,
  })  : hasArtistList = artists != null && artists.isNotEmpty,
        artists = (artists != null && artists.isNotEmpty) ? artists : guessArtists(artistName);

  /// The artists in a joined name, until the real list is known. Anything
  /// [ArtistNames.split] misses is repaired from the catalog (see
  /// ListenedTracksRepository).
  static List<String> guessArtists(String joined) => ArtistNames.split(joined);

  static List<String>? _artistsFrom(Object? raw) =>
      raw is List ? [for (final a in raw) if (a != null && a.toString().trim().isNotEmpty) a.toString().trim()] : null;

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
        artists: track.contributors.length > 1
            ? [for (final c in track.contributors) if (c.name.isNotEmpty) c.name]
            : [if (track.artistName.isNotEmpty) track.artistName],
      );

  ListenedTrackData withArtists(List<String> artists) => ListenedTrackData(
        trackId: trackId,
        title: title,
        artistName: artistName,
        albumTitle: albumTitle,
        albumId: albumId,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        duration: duration,
        listenedAt: listenedAt,
        artists: artists,
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
      artists: _artistsFrom(data['artists']),
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
      artists: _artistsFrom(json['artists']),
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
        if (hasArtistList) 'artists': artists,
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
        if (hasArtistList) 'artists': artists,
      };
}

/// The tracks the user marked as listened, synced with
/// `users/{uid}/listenedTracks` in Firestore and cached locally.
///
/// Marks and unmarks apply at once and are rolled back if Firestore rejects
/// them. The local cache is only saved once Firestore confirmed, so a write
/// that never lands can't leave a phantom track behind.
/// The listened songs, offline-first. The phone's database is the truth:
/// marking or unmarking writes it at once (with the outbox entry that will
/// tell the server, in the same transaction), the screens read an
/// in-memory mirror of it, and Firestore catches up through the outbox,
/// retrying until it lands. What other devices change arrives through
/// Firestore listeners and is merged into the database without undoing
/// changes still on their way up.
class ListenedTracksRepository {
  final FirebaseService _firebase;
  final StorageService _storage;
  final LibraryStore _store;
  final Outbox _outbox;
  final AlbumCompletionIndex _albums;
  final VoidCallback _onChanged;

  /// Runs a Firestore write while the library shows it is syncing.
  final Future<void> Function(Future<void> Function() write) _tracked;

  /// Looks a song up in the catalog, to learn the artists of old songs.
  final Future<Track?> Function(String trackId)? _lookupTrack;

  static const markKind = 'listened.upsert';
  static const unmarkKind = 'listened.delete';

  ListenedTracksRepository({
    required FirebaseService firebase,
    required StorageService storage,
    required LibraryStore store,
    required Outbox outbox,
    required AlbumCompletionIndex albums,
    required VoidCallback onChanged,
    required Future<void> Function(Future<void> Function() write) tracked,
    Future<Track?> Function(String trackId)? lookupTrack,
  })  : _firebase = firebase,
        _storage = storage,
        _store = store,
        _outbox = outbox,
        _albums = albums,
        _onChanged = onChanged,
        _tracked = tracked,
        _lookupTrack = lookupTrack {
    _outbox
      ..register(markKind, _sendMarks, onRefused: _marksRefused)
      ..register(unmarkKind, _sendUnmarks, onRefused: _unmarksRefused);
  }

  // The mirror of the database the screens read. Changes from the server
  // are applied to it one song at a time (a full re-read of a library of
  // thousands, on every confirmation while songs play, froze the screen),
  // so it also knows which songs have a change of this device's still on
  // its way up, the ones a server copy must not override.
  List<ListenedTrackData> _tracks = [];
  Set<String> _ids = {};
  final Set<String> _pendingMarks = {};
  final Set<String> _pendingUnmarks = {};
  bool _loaded = false;
  String? _uid;

  /// Last time the server refused a mark or unmark for good (and undid it
  /// here), until the next mark or unmark. The UI shows a snackbar for it;
  /// a later batch landing doesn't hide it.
  String? _lastSyncError;

  StreamSubscription? _tracksSubscription;
  StreamSubscription? _deletionsSubscription;

  // Distinct artists, rebuilt lazily after a change (see [invalidate]).
  bool _dirty = true;
  int _uniqueArtistsCount = 0;

  static const Duration _fullSyncInterval = Duration(hours: 4);
  static const Duration _deletionLogRetention = Duration(days: 7);

  /// Firestore batch sizes: 450 sets (+ the stats) and 240 deletes (each
  /// also writes the deletion log), under the 500-write limit.
  static const _markBatch = 450;
  static const _unmarkBatch = 240;

  // Test hooks, reached through LibraryRepositoryImpl: they stand in for
  // the Firestore write of a batch.
  Future<void> Function(List<ListenedTrackData> chunk, String uid)? markChunkHandlerForTesting;
  Future<void> Function(List<String> chunkIds, String uid)? unmarkChunkHandlerForTesting;

  // Read-only views, not copies: these are read on every rebuild and can hold
  // thousands of tracks. The same view is handed out until the tracks change,
  // so screens can skip work with identical(); every change replaces it.
  List<ListenedTrackData>? _tracksView;
  List<ListenedTrackData> get tracks => _tracksView ??= UnmodifiableListView(_tracks);
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
      // Each artist of each song: a collaboration counts its artists, not
      // the joined name as one more.
      _uniqueArtistsCount = {
        for (final t in _tracks)
          for (final a in t.artists) a.toLowerCase(),
      }.length;
      _dirty = false;
    }
    return _uniqueArtistsCount;
  }

  /// Reads the mirror back from the database: when opening the library,
  /// after a full download and after undoing a refused change. A change
  /// made here while it reads is kept (it reads again).
  Future<void> _reload(String uid) async {
    while (true) {
      final version = _localVersion;
      final rows = await _store.loadListened(uid);
      final pending = await _store.pendingListenedIds(uid);
      if (_uid != uid) return;
      if (version != _localVersion) continue;
      _tracks = rows.map(ListenedTrackData.fromJson).toList();
      _ids = _tracks.map((t) => t.trackId).toSet();
      _pendingMarks
        ..clear()
        ..addAll(pending.marks);
      _pendingUnmarks
        ..clear()
        ..addAll(pending.unmarks);
      _albums.prune();
      _changed();
      return;
    }
  }

  /// Bumped by every change made here, so a read that started before one
  /// doesn't replace the mirror with a list missing it.
  int _localVersion = 0;

  /// Applies the server's changes to the mirror, one song at a time,
  /// leaving alone the songs with a change of this device on its way up.
  void _applyRemote({List<ListenedTrackData> upserts = const [], List<String> removedIds = const []}) {
    var changed = false;
    for (final incoming in upserts) {
      if (_pendingUnmarks.contains(incoming.trackId)) continue;
      final idx = _tracks.indexWhere((t) => t.trackId == incoming.trackId);
      // A server copy of an old song has no artist list: keep the one known.
      final data = idx != -1 && !incoming.hasArtistList && _tracks[idx].hasArtistList
          ? incoming.withArtists(_tracks[idx].artists)
          : incoming;
      if (idx != -1) {
        _tracks[idx] = data;
      } else {
        _tracks.insert(0, data);
        _ids.add(data.trackId);
      }
      changed = true;
    }
    for (final id in removedIds) {
      if (_pendingMarks.contains(id) || !_ids.remove(id)) continue;
      _tracks.removeWhere((t) => t.trackId == id);
      changed = true;
    }
    if (!changed) return;
    _albums.prune();
    _changed();
  }

  /// Opens the account's library from the database, sends what was left
  /// pending last time, downloads everything when the last full sync is
  /// old, and listens for changes made elsewhere. Returns false when the
  /// user changed meanwhile ([isCurrent] went false), so the caller stops.
  Future<bool> connect(
    String uid,
    DocumentReference<Map<String, dynamic>> userDoc,
    bool Function() isCurrent,
  ) async {
    unawaited(_tracksSubscription?.cancel());
    unawaited(_deletionsSubscription?.cancel());
    _uid = uid;
    final tracksCol = userDoc.collection('listenedTracks');

    // 1. The database, at once (the old JSON library moves in first).
    try {
      if (!await _store.hasListened(uid)) {
        final legacy = await _storage.getCachedListenedTracks(uid);
        if (legacy.isNotEmpty && !await _store.hasListened(uid)) {
          await _store.saveListened(uid, legacy);
        }
      }
      if (!isCurrent()) return false;
      await _reload(uid);
      if (_tracks.isNotEmpty) _loaded = true;
    } catch (e) {
      _log.severe('opening the library failed: $e');
    }

    // 2. Whatever didn't reach the server last time goes now.
    _outbox.kick(uid);

    // 3. Full download only without local songs or when the last one is
    //    old; otherwise the delta listeners below are enough, so a cold
    //    start costs a handful of reads. It also picks up deletions made by
    //    clients that don't write the deletion log (the web app).
    final lastFullSync = await _storage.getLastListenedFullSync(uid);
    if (!isCurrent()) return false;
    final now = DateTime.now();
    final needsFullSync =
        _tracks.isEmpty || lastFullSync == null || now.difference(lastFullSync) > _fullSyncInterval;
    DateTime deletionsSince = (lastFullSync ?? now).subtract(const Duration(minutes: 5));

    if (needsFullSync) {
      try {
        final fetchStartedAt = DateTime.now();
        final snapshot = await tracksCol.orderBy('listenedAt', descending: true).get();
        if (!isCurrent()) return false;
        final server = [
          for (final doc in snapshot.docs) ListenedTrackData.fromFirestore(doc.data(), docId: doc.id).toJson(),
        ];
        await _store.replaceListenedWithServer(uid, server);
        if (!isCurrent()) return false;
        await _reload(uid);
        _loaded = true;
        _changed();
        unawaited(_storage.saveLastListenedFullSync(uid, fetchStartedAt));
        deletionsSince = fetchStartedAt.subtract(const Duration(minutes: 5));
        _reconcileServerStats(userDoc, snapshot.docs.length);
        _pruneDeletionLog(userDoc);
      } catch (e) {
        _log.severe('full download failed: $e');
      }
    }

    // 4. Delta listener: only docs newer than the latest known timestamp.
    //    The margin absorbs device clock skew in local entries.
    DateTime? deltaBoundary;
    for (final t in _tracks) {
      if (t.listenedAt != null && (deltaBoundary == null || t.listenedAt!.isAfter(deltaBoundary))) {
        deltaBoundary = t.listenedAt;
      }
    }
    if (deltaBoundary != null) {
      if (deltaBoundary.isAfter(now)) deltaBoundary = now;
      deltaBoundary = deltaBoundary.subtract(const Duration(minutes: 10));
    }
    final deltaQuery = deltaBoundary != null
        ? tracksCol
            .where('listenedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(deltaBoundary))
            .orderBy('listenedAt', descending: true)
        : tracksCol.orderBy('listenedAt', descending: true);

    _tracksSubscription = deltaQuery.snapshots().listen((snapshot) async {
      if (!isCurrent()) return;
      final upserts = <ListenedTrackData>[];
      final removed = <String>[];
      for (final change in snapshot.docChanges) {
        // This device's own write, not on the server yet: the database
        // already has it, as pending.
        if (change.doc.metadata.hasPendingWrites) continue;
        final docData = change.doc.data();
        if (docData == null) continue;
        final data = ListenedTrackData.fromFirestore(docData, docId: change.doc.id);
        if (change.type == DocumentChangeType.removed) {
          removed.add(data.trackId);
        } else {
          upserts.add(data);
        }
      }
      if (upserts.isEmpty && removed.isEmpty) return;
      // The screens at once, the database in the background (same rules).
      _loaded = true;
      _applyRemote(upserts: upserts, removedIds: removed);
      await _store.applyRemoteListened(uid, upserts: [for (final d in upserts) d.toJson()], removedIds: removed);
    }, onError: (e) {
      _log.severe('delta listener error: $e');
    });

    // 5. Deletion log: unmarks of tracks older than the delta boundary never
    //    show up as "removed" in the delta query, so unmarks also write
    //    listenedDeletions/{trackId} and other devices apply them from here.
    _deletionsSubscription = userDoc
        .collection('listenedDeletions')
        .where('deletedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(deletionsSince))
        .snapshots()
        .listen((snapshot) async {
      if (!isCurrent()) return;
      final deletions = <String, DateTime>{};
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final rawDeletedAt = change.doc.data()?['deletedAt'];
        // Pending local write (this device's own unmark): already applied.
        if (rawDeletedAt is! Timestamp) continue;
        deletions[change.doc.id] = rawDeletedAt.toDate();
      }
      if (deletions.isEmpty) return;
      var changed = false;
      deletions.forEach((id, at) {
        if (!_pendingMarks.contains(id) && _removeIfNotNewer(id, at)) changed = true;
      });
      if (changed) {
        _albums.prune();
        _changed();
      }
      await _store.applyRemoteDeletions(uid, deletions);
    }, onError: (e) {
      _log.severe('deletion log listener error: $e');
    });
    unawaited(_repairArtists(uid));
    return true;
  }

  /// Songs marked before their artist list was kept only have the names
  /// joined by commas, which can't tell "A, B" (two artists) from
  /// "Tyler, The Creator" (one). Those few get their real list from the
  /// catalog, in the background and gently (a few a second), and keep it.
  Future<void> _repairArtists(String uid, {Duration gap = const Duration(milliseconds: 250)}) async {
    final lookup = _lookupTrack;
    if (lookup == null) return;
    final todo = [
      for (final t in _tracks)
        if (!t.hasArtistList && t.artistName.contains(',')) t.trackId,
    ].take(500).toList();
    final found = <String, List<String>>{};

    Future<void> flush() async {
      if (found.isEmpty || _uid != uid) return;
      final batch = Map.of(found);
      found.clear();
      await _store.setListenedArtists(uid, batch);
      var changed = false;
      for (var i = 0; i < _tracks.length; i++) {
        final names = batch[_tracks[i].trackId];
        if (names != null) {
          _tracks[i] = _tracks[i].withArtists(names);
          changed = true;
        }
      }
      if (changed) _changed();
    }

    for (final id in todo) {
      if (_uid != uid) return;
      try {
        final track = await lookup(id);
        if (track != null) {
          found[id] = track.contributors.length > 1
              ? [for (final c in track.contributors) if (c.name.isNotEmpty) c.name]
              : [if (track.artistName.isNotEmpty) track.artistName];
        }
      } catch (e) {
        _log.severe('artist lookup for $id failed: $e');
      }
      if (found.length >= 20) await flush();
      await Future<void>.delayed(gap);
    }
    await flush();
  }

  void disconnect() {
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
    _tracksSubscription = null;
    _deletionsSubscription = null;
    _uid = null;
    _tracks = [];
    _ids = {};
    _pendingMarks.clear();
    _pendingUnmarks.clear();
    _loaded = false;
    _lastSyncError = null;
    _outbox.stop();
    invalidate();
  }

  /// Whether listening already started for the account's tracks.
  bool get isListening => _tracksSubscription != null;

  /// Completes once the writes in flight for [uid] are done.
  Future<void> idle(String uid) => _outbox.idle(uid);

  /// Sends what's pending now, without waiting for the next retry (the
  /// connection came back).
  Future<void> retryPending(String uid) => _outbox.retryNow(uid);

  /// Applies an unmark made on another device. A track re-marked after the
  /// deletion (newer listenedAt) is kept. Returns whether anything changed.
  bool applyRemoteDeletion(String trackId, DateTime deletedAt) {
    if (_pendingMarks.contains(trackId) || !_removeIfNotNewer(trackId, deletedAt)) return false;
    invalidate();
    final uid = _uid;
    if (uid != null) unawaited(_store.applyRemoteDeletions(uid, {trackId: deletedAt}));
    return true;
  }

  /// Drops [trackId] from the mirror unless it was marked after [deletedAt].
  bool _removeIfNotNewer(String trackId, DateTime deletedAt) {
    final idx = _tracks.indexWhere((t) => t.trackId == trackId);
    if (idx == -1) return false;
    final listenedAt = _tracks[idx].listenedAt;
    if (listenedAt != null && listenedAt.isAfter(deletedAt)) return false;
    _tracks.removeAt(idx);
    _ids.remove(trackId);
    return true;
  }

  /// stats.totalTracks (read by the web app) is the account's song count,
  /// written as a number, not an increment, so a write sent twice (the
  /// outbox and Firestore's own offline queue) can't count twice. The full
  /// download knows the server's real count and writes it too.
  void _reconcileServerStats(DocumentReference<Map<String, dynamic>> userDoc, int count) {
    userDoc.set({
      'stats': {'totalTracks': count},
    }, SetOptions(merge: true)).catchError((Object e) {
      _log.severe('stats reconcile failed: $e');
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
      batch.set(userDoc, {'lastSubWrite': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await SubWriteQueue.instance.run(batch.commit);
    }).catchError((Object e) {
      _log.severe('deletion log prune failed: $e');
    });
  }

  // Test hook, reached through LibraryRepositoryImpl.
  void setLoadedForTesting(bool loaded) => _loaded = loaded;

  // Test hook, reached through LibraryRepositoryImpl: [tracks] as the
  // account's synced library.
  Future<void> setTracksForTesting(List<ListenedTrackData> tracks, {String? uid}) {
    _tracks = List.from(tracks);
    _ids = tracks.map((t) => t.trackId).toSet();
    _loaded = true;
    invalidate();
    if (uid == null) return Future.value();
    _uid = uid;
    return _store.saveListened(uid, [for (final t in tracks) t.toJson()]);
  }

  // --- Writes: here first, then the outbox tells the server

  Future<void> mark(String uid, Track track) => markAll(uid, [track]);

  /// Marks the songs of [tracks] not listened yet.
  Future<void> markAll(String uid, List<Track> tracks) async {
    final seen = <String>{};
    final toMark = [
      for (final t in tracks)
        if (!_ids.contains(t.id) && seen.add(t.id)) t,
    ];
    if (toMark.isEmpty) return;
    _uid = uid;

    final data = toMark.map(ListenedTrackData.fromTrack).toList();
    _localVersion++;
    _tracks.addAll(data);
    _ids.addAll(toMark.map((t) => t.id));
    for (final t in toMark) {
      _pendingUnmarks.remove(t.id);
      _pendingMarks.add(t.id);
    }
    if (toMark.length > 1 || (toMark.first.albumId.isNotEmpty && _albums.hasTrackCount(toMark.first.albumId))) {
      _albums.prune(forceSave: true);
    }
    _lastSyncError = null;
    _changed();

    final ids = [for (final t in toMark) t.id];
    await _store.markListenedLocally(uid, [for (final d in data) d.toJson()], () async {
      for (final chunk in ids.slices(_markBatch)) {
        await _outbox.enqueue(uid, markKind, chunk.first, {'ids': chunk});
      }
    });
    _outbox.kick(uid);
  }

  Future<void> unmark(String uid, String trackId) => unmarkAll(uid, [trackId]);

  /// Unmarks the listened ones among [trackIds].
  Future<void> unmarkAll(String uid, List<String> trackIds) async {
    final toUnmark = trackIds.toSet().where(_ids.contains).toList();
    if (toUnmark.isEmpty) return;
    _uid = uid;

    final gone = toUnmark.toSet();
    _localVersion++;
    _tracks.removeWhere((t) => gone.contains(t.trackId));
    _ids.removeAll(gone);
    _pendingMarks.removeAll(gone);
    _pendingUnmarks.addAll(gone);
    _albums.prune();
    _lastSyncError = null;
    _changed();

    await _store.unmarkListenedLocally(uid, toUnmark, () async {
      for (final chunk in toUnmark.slices(_unmarkBatch)) {
        await _outbox.enqueue(uid, unmarkKind, chunk.first, {'ids': chunk});
      }
    });
    _outbox.kick(uid);
  }

  static List<String> _idsOf(OutboxEntry entry) =>
      [for (final id in entry.payload['ids'] as List) id.toString()];

  /// Outbox: one batch of marks to Firestore (the songs as the database has
  /// them now; one unmarked since is left to its own delete entry).
  Future<void> _sendMarks(OutboxEntry entry) async {
    final uid = entry.uid;
    final ids = _idsOf(entry);
    final rows = (await _store.listenedByIds(uid, ids)).map(ListenedTrackData.fromJson).toList();
    if (rows.isNotEmpty) {
      await _tracked(() async {
        final testHandler = markChunkHandlerForTesting;
        if (testHandler != null) return testHandler(rows, uid);
        final total = await _store.countListened(uid);
        await sendToFirestore(() async {
          final db = _firebase.db;
          final userDoc = db.collection('users').doc(uid);
          final batch = db.batch();
          for (final data in rows) {
            batch.set(userDoc.collection('listenedTracks').doc(data.trackId), data.toFirestore(),
                SetOptions(merge: true));
          }
          batch.set(userDoc, {
            'stats': {'totalTracks': total},
            'lastSubWrite': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await SubWriteQueue.instance.run(batch.commit);
        });
      });
    }
    await _store.confirmListenedUpserts(uid, ids);
    if (_uid == uid) _pendingMarks.removeAll(ids);
  }

  /// Outbox: one batch of unmarks to Firestore, with the deletion log.
  Future<void> _sendUnmarks(OutboxEntry entry) async {
    final uid = entry.uid;
    final ids = _idsOf(entry);
    await _tracked(() async {
      final testHandler = unmarkChunkHandlerForTesting;
      if (testHandler != null) return testHandler(ids, uid);
      final total = await _store.countListened(uid);
      await sendToFirestore(() async {
        final db = _firebase.db;
        final userDoc = db.collection('users').doc(uid);
        final batch = db.batch();
        for (final id in ids) {
          batch.delete(userDoc.collection('listenedTracks').doc(id));
          batch.set(userDoc.collection('listenedDeletions').doc(id), {
            'deletedAt': FieldValue.serverTimestamp(),
          });
        }
        batch.set(userDoc, {
          'stats': {'totalTracks': total},
          'lastSubWrite': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await SubWriteQueue.instance.run(batch.commit);
      });
    });
    await _store.confirmListenedDeletes(uid, ids);
    if (_uid == uid) _pendingUnmarks.removeAll(ids);
  }

  void _marksRefused(OutboxEntry entry, Object error) {
    unawaited(_undo(entry.uid, 'mark_failed', () => _store.revertListenedUpserts(entry.uid, _idsOf(entry))));
  }

  void _unmarksRefused(OutboxEntry entry, Object error) {
    unawaited(_undo(entry.uid, 'unmark_failed', () => _store.revertListenedDeletes(entry.uid, _idsOf(entry))));
  }

  /// The server refused a change for good: undo it here and say so.
  Future<void> _undo(String uid, String error, Future<void> Function() revert) async {
    await revert();
    if (_uid != uid) return;
    _lastSyncError = error;
    await _reload(uid);
  }

  void dispose() {
    _tracksSubscription?.cancel();
    _deletionsSubscription?.cancel();
  }
}
