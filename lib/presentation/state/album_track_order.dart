import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/listened_track.dart';
import 'use_cases.dart';

/// The order of each album's songs, as the album lists them.
///
/// The library keeps songs in the order they were marked; this puts an
/// album's songs back in the album's own order, to show it and to play it.
/// Each album is asked for once and kept on the phone for good (an album's
/// order doesn't change).
class AlbumTrackOrder extends ChangeNotifier {
  AlbumTrackOrder({required Future<List<String>?> Function(String albumId) fetch}) : _fetch = fetch {
    _loading = _load();
  }

  static const storageKey = 'album_track_order_v1';

  /// Albums kept on the phone; the ones learnt first go first past it.
  static const maxAlbums = 1500;

  final Future<List<String>?> Function(String albumId) _fetch;
  final Map<String, List<String>> _order = {};
  final Map<String, Future<List<String>?>> _inFlight = {};
  // Albums the catalog couldn't give this session: not asked again until
  // the app restarts, so an offline phone doesn't keep asking.
  final Set<String> _failed = {};
  late final Future<void> _loading;
  Timer? _saveTimer;
  bool _disposed = false;

  /// The album's song ids in order, or null while it isn't known.
  List<String>? orderOf(String albumId) => _order[albumId];

  /// The album's order, asked for once if it isn't known yet. Null when it
  /// can't be had (no id, no network): then the marked order stands.
  Future<List<String>?> ensure(String albumId) {
    if (albumId.isEmpty) return Future.value();
    final known = _order[albumId];
    if (known != null) return SynchronousFuture(known);
    if (_failed.contains(albumId)) return Future.value();
    return _inFlight[albumId] ??= _fetchOne(albumId);
  }

  Future<List<String>?> _fetchOne(String albumId) async {
    try {
      // What's saved on the phone first (it's read as the library opens),
      // but never held up for long by it.
      await _loading.timeout(const Duration(milliseconds: 500), onTimeout: () {});
      final stored = _order[albumId];
      if (stored != null) return stored;
      final ids = await _fetch(albumId);
      if (ids == null || ids.isEmpty) {
        _failed.add(albumId);
        return null;
      }
      final order = List<String>.unmodifiable(ids);
      _order[albumId] = order;
      while (_order.length > maxAlbums) {
        _order.remove(_order.keys.first);
      }
      _scheduleSave();
      if (!_disposed) notifyListeners();
      return order;
    } catch (_) {
      _failed.add(albumId);
      return null;
    } finally {
      unawaited(_inFlight.remove(albumId));
    }
  }

  /// [tracks] (one album's songs from the library) in the album's order.
  /// Without it, or for songs it doesn't list, the order they were marked
  /// in, oldest first: marking a whole album marks its songs in order.
  List<ListenedTrackData> sort(String albumId, List<ListenedTrackData> tracks) =>
      sortByAlbum(tracks, _order[albumId]);

  /// The song's number on its album (1 for the first), or null.
  int? numberOf(String albumId, String trackId) {
    final i = _order[albumId]?.indexOf(trackId) ?? -1;
    return i < 0 ? null : i + 1;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      var added = false;
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (value is! List || _order.containsKey(key)) continue;
        _order[key.toString()] = List.unmodifiable([for (final id in value) id.toString()]);
        added = true;
      }
      if (added && !_disposed) notifyListeners();
    } catch (_) {
      // A damaged entry only costs asking the albums again.
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () => unawaited(_save()));
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json.encode(_order));
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_save());
    }
    super.dispose();
  }
}

/// [tracks] in [order] (an album's song ids); songs it doesn't list, or all
/// of them without one, in the order they were marked, oldest first (the
/// library lists the newest first).
List<ListenedTrackData> sortByAlbum(List<ListenedTrackData> tracks, List<String>? order) {
  final oldestFirst = tracks.reversed.toList();
  if (order == null || order.isEmpty || tracks.length < 2) return oldestFirst;
  final position = {for (var i = 0; i < order.length; i++) order[i]: i};
  final known = [for (final t in oldestFirst) if (position.containsKey(t.trackId)) t]
    ..sort((a, b) => position[a.trackId]!.compareTo(position[b.trackId]!));
  return [...known, for (final t in oldestFirst) if (!position.containsKey(t.trackId)) t];
}

/// Kept for the app's life. The catalog is only reached when an album's
/// order is first needed.
final albumTrackOrderProvider = ChangeNotifierProvider<AlbumTrackOrder>((ref) {
  return AlbumTrackOrder(fetch: (albumId) async {
    final album = await ref.read(musicCatalogProvider).getAlbum(albumId);
    return album?.tracks.map((t) => t.id).toList();
  });
});
