import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logger.dart';
import '../../domain/logic/beat_clock.dart';

export '../../domain/logic/beat_clock.dart';


final _log = Log.named('BeatSync');

/// Where the beats of a song fall: its tempo plus the offset of a beat.
///
/// Times are in song (media) time, so a song sped up for Run mode keeps its
/// beats aligned without any correction.
class BeatSyncStore {
  static final BeatSyncStore shared = BeatSyncStore();
  static const _key = 'beat_sync_v1';
  static const int maxEntries = 300;

  final Map<String, BeatGrid> _grids = {};
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
        final g = BeatGrid.fromJson(v);
        if (g != null) _grids[k] = g;
      });
    } catch (e) {
      _log.severe('load error: $e');
    }
  }

  static String keyFor(String trackId, {required bool fullSong}) =>
      beatSyncKey(trackId, fullSong: fullSong);

  BeatGrid? get(String key) => _grids[key];

  Future<void> put(String key, BeatGrid grid) async {
    _grids.remove(key);
    _grids[key] = grid;
    while (_grids.length > maxEntries) {
      _grids.remove(_grids.keys.first);
    }
    await _save();
  }

  Future<void> remove(String key) async {
    if (_grids.remove(key) != null) await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode({for (final e in _grids.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }
}
