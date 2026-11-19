import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../domain/entities/track.dart';
import 'blob_store.dart';


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
      // Files of their own (BlobStore), not SharedPreferences: see there.
      final rawLog = await BlobStore.read(_logKey);
      final rawTracks = await BlobStore.read(_tracksKey);
      // Perf: up to 2000 songs (a megabyte or more), read as the app
      // starts: decoded on a worker isolate, not under the entrance.
      final (entries, tracks) = (rawLog?.length ?? 0) + (rawTracks?.length ?? 0) > _isolateFrom
          ? await Isolate.run(() => _parse(rawLog, rawTracks))
          : _parse(rawLog, rawTracks);
      _tracks.addAll(tracks);
      _entries.addAll(entries);
      notifyListeners();
    } catch (e) {
      _log.severe('load error: $e');
    }
  }

  /// From this size on, parsed off the UI isolate.
  static const int _isolateFrom = 32 * 1024;

  static (List<PlayEntry>, Map<String, Track>) _parse(String? rawLog, String? rawTracks) {
    final tracks = <String, Track>{};
    final entries = <PlayEntry>[];
    if (rawTracks != null) {
      (jsonDecode(rawTracks) as Map<String, dynamic>).forEach((id, json) {
        tracks[id] = Track.fromJson(Map<String, dynamic>.from(json as Map));
      });
    }
    if (rawLog != null) {
      for (final e in jsonDecode(rawLog) as List) {
        final pair = e as List;
        entries.add(PlayEntry(pair[0] as String,
            DateTime.fromMillisecondsSinceEpoch((pair[1] as int) * 1000, isUtc: true)));
      }
    }
    return (entries, tracks);
  }

  /// Each song's JSON, written once: saving after a play encodes the new
  /// song only, not the thousands already kept (perf: it ran on every play,
  /// on the UI thread).
  final Map<String, String> _trackJson = {};

  String _encodeTracks() {
    final out = StringBuffer('{');
    var first = true;
    for (final MapEntry(key: id, value: track) in _tracks.entries) {
      if (!first) out.write(',');
      first = false;
      out
        ..write(jsonEncode(id))
        ..write(':')
        ..write(_trackJson[id] ??= jsonEncode(track.toJson()));
    }
    out.write('}');
    return out.toString();
  }

  Future<void> record(Track track, {DateTime? at}) async {
    if (track.id.isEmpty) return;
    await load();
    _entries.add(PlayEntry(track.id, (at ?? DateTime.now()).toUtc()));
    if (_tracks[track.id] != track) _trackJson.remove(track.id);
    _tracks[track.id] = track;
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
      final live = _entries.map((e) => e.trackId).toSet();
      _tracks.removeWhere((id, _) => !live.contains(id));
      _trackJson.removeWhere((id, _) => !live.contains(id));
    }
    notifyListeners();
    try {
      await BlobStore.write(
        _logKey,
        jsonEncode(_entries
            .map((e) => [e.trackId, e.at.millisecondsSinceEpoch ~/ 1000])
            .toList()),
      );
      await BlobStore.write(_tracksKey, _encodeTracks());
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
