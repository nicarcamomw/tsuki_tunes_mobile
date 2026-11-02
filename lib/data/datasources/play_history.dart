import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/track.dart';
import '../../core/logger.dart';


final _log = Log.named('PlayHistory');

class PlayEntry {
  final String trackId;
  final DateTime at;

  const PlayEntry(this.trackId, this.at);
}

/// Local log of counted plays (see AudioProvider.onPlayCounted), used to
/// build the full-moon mix from what the user really listened to.
class PlayHistory extends ChangeNotifier {
  static const _logKey = 'play_log_v1';
  static const _tracksKey = 'play_log_tracks_v1';
  static const int maxEntries = 2000;

  final List<PlayEntry> _entries = [];
  final Map<String, Track> _tracks = {};
  Future<void>? _loading;

  List<PlayEntry> get entries => List.unmodifiable(_entries);
  Map<String, Track> get tracks => Map.unmodifiable(_tracks);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLog = prefs.getString(_logKey);
      final rawTracks = prefs.getString(_tracksKey);
      if (rawTracks != null) {
        final m = jsonDecode(rawTracks) as Map<String, dynamic>;
        m.forEach((id, json) {
          _tracks[id] = Track.fromJson(Map<String, dynamic>.from(json as Map));
        });
      }
      if (rawLog != null) {
        for (final e in jsonDecode(rawLog) as List) {
          final pair = e as List;
          _entries.add(PlayEntry(pair[0] as String,
              DateTime.fromMillisecondsSinceEpoch((pair[1] as int) * 1000, isUtc: true)));
        }
      }
      notifyListeners();
    } catch (e) {
      _log.severe('load error: $e');
    }
  }

  Future<void> record(Track track, {DateTime? at}) async {
    if (track.id.isEmpty) return;
    await load();
    _entries.add(PlayEntry(track.id, (at ?? DateTime.now()).toUtc()));
    _tracks[track.id] = track;
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
      final live = _entries.map((e) => e.trackId).toSet();
      _tracks.removeWhere((id, _) => !live.contains(id));
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _logKey,
        jsonEncode(_entries
            .map((e) => [e.trackId, e.at.millisecondsSinceEpoch ~/ 1000])
            .toList()),
      );
      await prefs.setString(
        _tracksKey,
        jsonEncode(_tracks.map((id, t) => MapEntry(id, t.toJson()))),
      );
    } catch (e) {
      _log.severe('save error: $e');
    }
  }

  /// Most played tracks in [from, to]: by play count, ties broken by the most
  /// recent play.
  static List<Track> rank({
    required List<PlayEntry> entries,
    required Map<String, Track> tracks,
    required DateTime from,
    required DateTime to,
    int limit = 25,
  }) {
    final counts = <String, int>{};
    final last = <String, DateTime>{};
    for (final e in entries) {
      if (e.at.isBefore(from) || e.at.isAfter(to)) continue;
      if (!tracks.containsKey(e.trackId)) continue;
      counts[e.trackId] = (counts[e.trackId] ?? 0) + 1;
      final prev = last[e.trackId];
      if (prev == null || e.at.isAfter(prev)) last[e.trackId] = e.at;
    }
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : last[b]!.compareTo(last[a]!);
      });
    return ids.take(limit).map((id) => tracks[id]!).toList();
  }

  List<Track> topBetween(DateTime from, DateTime to, {int limit = 25}) =>
      rank(entries: _entries, tracks: _tracks, from: from, to: to, limit: limit);

  /// Number of unique tracks played in [from, to]. O(n) scan, no sorting.
  int countBetween(DateTime from, DateTime to) {
    final seen = <String>{};
    for (final e in _entries) {
      if (e.at.isBefore(from) || e.at.isAfter(to)) continue;
      if (!_tracks.containsKey(e.trackId)) continue;
      seen.add(e.trackId);
    }
    return seen.length;
  }
}
