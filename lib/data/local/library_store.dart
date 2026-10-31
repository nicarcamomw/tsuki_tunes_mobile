import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// The repositories keep their lists in memory and hand them over whole to
/// be saved; this writes them to SQLite row by row. Each save compares
/// with what it wrote last for that account and touches only the rows that
/// changed, in one transaction: marking a song writes one row, not the
/// whole library. Saves run one after another, so an older list never
/// lands last.
class LibraryStore {
  LibraryStore(this._db);

  final AppDatabase _db;
  Future<void> _writes = Future.value();

  static const _rowEquality = DeepCollectionEquality();

  // What the database holds, per account, as last read or written.
  final _listened = <String, Map<String, Map<String, dynamic>>>{};
  final _playlists = <String, Map<String, (int, String)>>{};
  final _followed = <String, Map<String, (int, String)>>{};

  /// Runs after every earlier save (reads too, so they see it).
  Future<T> _queued<T>(Future<T> Function() task) {
    final result = _writes.then((_) => task());
    _writes = result.then((_) {}, onError: (_) {});
    return result;
  }

  // --- Listened songs (the maps ListenedTrackData.toJson writes)

  Future<List<Map<String, dynamic>>> loadListened(String uid) => _queued(() async {
        final rows = await (_db.select(_db.listenedTracks)
              ..where((t) => t.uid.equals(uid) & t.syncState.equals(SyncState.pendingDelete).not())
              ..orderBy([
                (t) => OrderingTerm(expression: t.listenedAt, mode: OrderingMode.desc, nulls: NullsOrder.last),
              ]))
            .get();
        final maps = [for (final r in rows) _listenedToMap(r)];
        _listened[uid] = {for (final m in maps) m['trackId'] as String: m};
        return maps;
      });

  Future<bool> hasListened(String uid) => _queued(() async {
        final count = _db.listenedTracks.trackId.count();
        final query = _db.selectOnly(_db.listenedTracks)
          ..addColumns([count])
          ..where(_db.listenedTracks.uid.equals(uid));
        return (await query.map((r) => r.read(count)).getSingle() ?? 0) > 0;
      });

  Future<void> saveListened(String uid, List<Map<String, dynamic>> tracks) => _queued(() async {
        final before = _listened[uid] ?? await _readListenedIds(uid);
        final after = {for (final t in tracks) t['trackId'].toString(): t};
        final removed = before.keys.where((id) => !after.containsKey(id)).toList();
        final changed = [
          for (final e in after.entries)
            if (!_rowEquality.equals(before[e.key], e.value)) e.value,
        ];
        if (removed.isEmpty && changed.isEmpty) return;
        await _db.batch((b) {
          for (final chunk in removed.slices(500)) {
            b.deleteWhere(_db.listenedTracks, (t) => t.uid.equals(uid) & t.trackId.isIn(chunk));
          }
          b.insertAllOnConflictUpdate(_db.listenedTracks, [for (final t in changed) _listenedRow(uid, t)]);
        });
        _listened[uid] = after;
      });

  Future<Map<String, Map<String, dynamic>>> _readListenedIds(String uid) async {
    final rows = await (_db.select(_db.listenedTracks)
          ..where((t) => t.uid.equals(uid) & t.syncState.equals(SyncState.pendingDelete).not()))
        .get();
    return {for (final r in rows) r.trackId: _listenedToMap(r)};
  }

  // --- Listened songs, offline-first: the database is the truth, the
  // server catches up through the outbox. Each local change and its outbox
  // entry are written in one transaction ([enqueue] runs inside it).

  /// Marks songs here (pending until the server has them).
  Future<void> markListenedLocally(
    String uid,
    List<Map<String, dynamic>> tracks,
    Future<void> Function() enqueue,
  ) =>
      _queued(() => _db.transaction(() async {
            await _db.batch((b) => b.insertAllOnConflictUpdate(_db.listenedTracks, [
                  for (final t in tracks)
                    _listenedRow(uid, t).copyWith(syncState: const Value(SyncState.pendingUpsert)),
                ]));
            await enqueue();
            final known = _listened[uid];
            if (known != null) {
              for (final t in tracks) {
                known[t['trackId'].toString()] = t;
              }
            }
          }));

  /// Unmarks songs here: they stay as hidden tombstones until the server
  /// confirms, so a copy coming back from it can't revive them.
  Future<void> unmarkListenedLocally(String uid, List<String> ids, Future<void> Function() enqueue) =>
      _queued(() => _db.transaction(() async {
            await _setState(uid, ids, SyncState.pendingDelete);
            await enqueue();
            _listened[uid]?.removeWhere((id, _) => ids.contains(id));
          }));

  /// The server has these marks now.
  Future<void> confirmListenedUpserts(String uid, List<String> ids) =>
      _queued(() => _setState(uid, ids, SyncState.synced, onlyFrom: SyncState.pendingUpsert));

  /// The server deleted these: the tombstones can go.
  Future<void> confirmListenedDeletes(String uid, List<String> ids) => _queued(() async {
        for (final chunk in ids.slices(500)) {
          await (_db.delete(_db.listenedTracks)
                ..where((t) =>
                    t.uid.equals(uid) & t.trackId.isIn(chunk) & t.syncState.equals(SyncState.pendingDelete)))
              .go();
        }
      });

  /// The server refused these marks for good: undo them here.
  Future<void> revertListenedUpserts(String uid, List<String> ids) => _queued(() async {
        for (final chunk in ids.slices(500)) {
          await (_db.delete(_db.listenedTracks)
                ..where((t) =>
                    t.uid.equals(uid) & t.trackId.isIn(chunk) & t.syncState.equals(SyncState.pendingUpsert)))
              .go();
        }
        _listened.remove(uid);
      });

  /// The server refused these unmarks for good: the songs come back.
  Future<void> revertListenedDeletes(String uid, List<String> ids) => _queued(() async {
        await _setState(uid, ids, SyncState.synced, onlyFrom: SyncState.pendingDelete);
        _listened.remove(uid);
      });

  /// The visible songs among [ids], as the server should get them.
  Future<List<Map<String, dynamic>>> listenedByIds(String uid, List<String> ids) => _queued(() async {
        final out = <Map<String, dynamic>>[];
        for (final chunk in ids.slices(500)) {
          final rows = await (_db.select(_db.listenedTracks)
                ..where((t) =>
                    t.uid.equals(uid) &
                    t.trackId.isIn(chunk) &
                    t.syncState.equals(SyncState.pendingDelete).not()))
              .get();
          out.addAll(rows.map(_listenedToMap));
        }
        return out;
      });

  /// How many songs the account has listened (tombstones aside).
  Future<int> countListened(String uid) => _queued(() async {
        final count = _db.listenedTracks.trackId.count();
        final query = _db.selectOnly(_db.listenedTracks)
          ..addColumns([count])
          ..where(_db.listenedTracks.uid.equals(uid) &
              _db.listenedTracks.syncState.equals(SyncState.pendingDelete).not());
        return await query.map((r) => r.read(count)).getSingle() ?? 0;
      });

  /// Changes made on the server (another device): [upserts] arrive as
  /// synced unless unmarked here meanwhile; [removedIds] only take synced
  /// songs, never a mark still on its way up.
  Future<void> applyRemoteListened(
    String uid, {
    List<Map<String, dynamic>> upserts = const [],
    List<String> removedIds = const [],
  }) =>
      _queued(() => _db.transaction(() async {
            final tombstones = await _idsInState(uid, SyncState.pendingDelete);
            await _db.batch((b) {
              b.insertAllOnConflictUpdate(_db.listenedTracks, [
                for (final t in upserts)
                  if (!tombstones.contains(t['trackId'].toString()))
                    _listenedRow(uid, t).copyWith(syncState: const Value(SyncState.synced)),
              ]);
              for (final chunk in removedIds.slices(500)) {
                b.deleteWhere(
                  _db.listenedTracks,
                  (t) => t.uid.equals(uid) & t.trackId.isIn(chunk) & t.syncState.equals(SyncState.synced),
                );
              }
            });
            _listened.remove(uid);
          }));

  /// A full download from the server: it becomes the synced set, while
  /// local changes still on their way up (marks and tombstones) stay.
  Future<void> replaceListenedWithServer(String uid, List<Map<String, dynamic>> server) =>
      _queued(() => _db.transaction(() async {
            final serverIds = {for (final t in server) t['trackId'].toString()};
            final synced = await _idsInState(uid, SyncState.synced);
            final gone = synced.where((id) => !serverIds.contains(id)).toList();
            final tombstones = await _idsInState(uid, SyncState.pendingDelete);
            await _db.batch((b) {
              for (final chunk in gone.slices(500)) {
                b.deleteWhere(_db.listenedTracks, (t) => t.uid.equals(uid) & t.trackId.isIn(chunk));
              }
              b.insertAllOnConflictUpdate(_db.listenedTracks, [
                for (final t in server)
                  if (!tombstones.contains(t['trackId'].toString()))
                    _listenedRow(uid, t).copyWith(syncState: const Value(SyncState.synced)),
              ]);
            });
            _listened.remove(uid);
          }));

  /// Unmarks made on another device (the deletion log): a synced song goes
  /// unless it was marked again after the unmark.
  Future<void> applyRemoteDeletions(String uid, Map<String, DateTime> deletedAt) =>
      _queued(() => _db.transaction(() async {
            for (final e in deletedAt.entries) {
              await (_db.delete(_db.listenedTracks)
                    ..where((t) =>
                        t.uid.equals(uid) &
                        t.trackId.equals(e.key) &
                        t.syncState.equals(SyncState.synced) &
                        (t.listenedAt.isNull() | t.listenedAt.isSmallerOrEqualValue(e.value))))
                  .go();
            }
            _listened.remove(uid);
          }));

  Future<void> _setState(String uid, List<String> ids, int state, {int? onlyFrom}) async {
    for (final chunk in ids.slices(500)) {
      await (_db.update(_db.listenedTracks)
            ..where((t) {
              final match = t.uid.equals(uid) & t.trackId.isIn(chunk);
              return onlyFrom == null ? match : match & t.syncState.equals(onlyFrom);
            }))
          .write(ListenedTracksCompanion(syncState: Value(state)));
    }
  }

  Future<Set<String>> _idsInState(String uid, int state) async {
    final rows = await (_db.selectOnly(_db.listenedTracks)
          ..addColumns([_db.listenedTracks.trackId])
          ..where(_db.listenedTracks.uid.equals(uid) & _db.listenedTracks.syncState.equals(state)))
        .get();
    return {for (final r in rows) r.read(_db.listenedTracks.trackId)!};
  }

  static Map<String, dynamic> _listenedToMap(ListenedTrack r) => {
        'trackId': r.trackId,
        'title': r.title,
        'artistName': r.artistName,
        'albumTitle': r.albumTitle,
        'albumId': r.albumId,
        'coverUrl': r.coverUrl,
        'previewUrl': r.previewUrl,
        'duration': r.duration,
        'listenedAt': r.listenedAt?.toIso8601String(),
      };

  static ListenedTracksCompanion _listenedRow(String uid, Map<String, dynamic> t) =>
      ListenedTracksCompanion.insert(
        uid: uid,
        trackId: t['trackId'].toString(),
        title: t['title']?.toString() ?? '',
        artistName: t['artistName']?.toString() ?? '',
        albumTitle: t['albumTitle']?.toString() ?? '',
        albumId: t['albumId']?.toString() ?? '',
        coverUrl: t['coverUrl']?.toString() ?? '',
        previewUrl: Value(t['previewUrl']?.toString() ?? ''),
        duration: t['duration'] is num ? (t['duration'] as num).toInt() : 0,
        listenedAt: Value(DateTime.tryParse(t['listenedAt']?.toString() ?? '')),
      );

  // --- Playlists and followed artists: one JSON row each, in order

  Future<List<Map<String, dynamic>>> loadPlaylists(String uid) => _queued(() async {
        final rows = await (_db.select(_db.playlists)
              ..where((t) => t.uid.equals(uid))
              ..orderBy([(t) => OrderingTerm(expression: t.position)]))
            .get();
        _playlists[uid] = {for (final r in rows) r.id: (r.position, r.json)};
        return [for (final r in rows) Map<String, dynamic>.from(json.decode(r.json) as Map)];
      });

  /// Saves the playlists; [alsoInTransaction] (an outbox entry) is
  /// written with them, so both are kept or neither.
  Future<void> savePlaylists(
    String uid,
    List<Map<String, dynamic>> playlists, {
    Future<void> Function()? alsoInTransaction,
  }) =>
      _queued(() => _db.transaction(() async {
        final before = _playlists[uid] ??
            {
              for (final r in await (_db.select(_db.playlists)..where((t) => t.uid.equals(uid))).get())
                r.id: (r.position, r.json),
            };
        final after = {
          for (final (i, p) in playlists.indexed) p['id'].toString(): (i, json.encode(p)),
        };
        await _db.batch((b) {
          final removed = before.keys.where((id) => !after.containsKey(id)).toList();
          if (removed.isNotEmpty) {
            b.deleteWhere(_db.playlists, (t) => t.uid.equals(uid) & t.id.isIn(removed));
          }
          b.insertAllOnConflictUpdate(_db.playlists, [
            for (final e in after.entries)
              if (before[e.key] != e.value)
                PlaylistsCompanion.insert(uid: uid, id: e.key, position: e.value.$1, json: e.value.$2),
          ]);
        });
        await alsoInTransaction?.call();
        _playlists[uid] = after;
      }));

  Future<void> clearPlaylists(String uid) => _queued(() async {
        await (_db.delete(_db.playlists)..where((t) => t.uid.equals(uid))).go();
        _playlists[uid] = {};
      });

  Future<List<Map<String, dynamic>>> loadFollowed(String uid) => _queued(() async {
        final rows = await (_db.select(_db.followedArtists)
              ..where((t) => t.uid.equals(uid))
              ..orderBy([(t) => OrderingTerm(expression: t.position)]))
            .get();
        _followed[uid] = {for (final r in rows) r.artistId: (r.position, r.json)};
        return [for (final r in rows) Map<String, dynamic>.from(json.decode(r.json) as Map)];
      });

  /// Saves the followed artists; [alsoInTransaction] (an outbox entry)
  /// is written with them, so both are kept or neither.
  Future<void> saveFollowed(
    String uid,
    List<Map<String, dynamic>> artists, {
    Future<void> Function()? alsoInTransaction,
  }) =>
      _queued(() => _db.transaction(() async {
        final before = _followed[uid] ??
            {
              for (final r in await (_db.select(_db.followedArtists)..where((t) => t.uid.equals(uid))).get())
                r.artistId: (r.position, r.json),
            };
        final after = {
          for (final (i, a) in artists.indexed) a['id'].toString(): (i, json.encode(a)),
        };
        await _db.batch((b) {
          final removed = before.keys.where((id) => !after.containsKey(id)).toList();
          if (removed.isNotEmpty) {
            b.deleteWhere(_db.followedArtists, (t) => t.uid.equals(uid) & t.artistId.isIn(removed));
          }
          b.insertAllOnConflictUpdate(_db.followedArtists, [
            for (final e in after.entries)
              if (before[e.key] != e.value)
                FollowedArtistsCompanion.insert(
                    uid: uid, artistId: e.key, position: e.value.$1, json: e.value.$2),
          ]);
        });
        await alsoInTransaction?.call();
        _followed[uid] = after;
      }));
}
