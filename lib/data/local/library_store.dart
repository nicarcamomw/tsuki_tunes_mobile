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
              ..where((t) => t.uid.equals(uid))
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
    final rows = await (_db.select(_db.listenedTracks)..where((t) => t.uid.equals(uid))).get();
    return {for (final r in rows) r.trackId: _listenedToMap(r)};
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

  Future<void> savePlaylists(String uid, List<Map<String, dynamic>> playlists) => _queued(() async {
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
        _playlists[uid] = after;
      });

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

  Future<void> saveFollowed(String uid, List<Map<String, dynamic>> artists) => _queued(() async {
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
        _followed[uid] = after;
      });
}
