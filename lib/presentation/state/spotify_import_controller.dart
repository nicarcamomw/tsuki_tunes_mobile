import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../domain/entities/external_library.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/track_matcher.dart';

final _log = Log.named('SpotifyImport');

/// How one playlist went.
class ImportResult {
  const ImportResult({required this.name, required this.found, required this.total, this.playlistId});

  final String name;
  final int found;
  final int total;
  final String? playlistId;
}

/// Brings Spotify playlists (and the saved songs) into Tsuki: each song is
/// looked up in the catalog (by ISRC, then by title and artist) and the
/// ones found make a Tsuki playlist with the same name.
class SpotifyImportController extends ChangeNotifier {
  SpotifyImportController({
    required Future<List<ExternalPlaylist>> Function() loadPlaylists,
    required Future<List<ExternalTrack>> Function(ExternalPlaylist p) loadTracks,
    required bool Function() needsReconnect,
    required TrackMatcher matcher,
    required Future<Playlist?> Function(String name, List<Track> tracks) createPlaylist,
    required String likedName,
    this.gap = const Duration(milliseconds: 120),
  })  : _loadPlaylists = loadPlaylists,
        _loadTracks = loadTracks,
        _needsReconnect = needsReconnect,
        _matcher = matcher,
        _create = createPlaylist,
        _likedName = likedName;

  final Future<List<ExternalPlaylist>> Function() _loadPlaylists;
  final Future<List<ExternalTrack>> Function(ExternalPlaylist p) _loadTracks;
  final bool Function() _needsReconnect;
  final TrackMatcher _matcher;
  final Future<Playlist?> Function(String name, List<Track> tracks) _create;
  final String _likedName;

  /// Between catalog lookups: Deezer allows about 10 a second.
  final Duration gap;

  List<ExternalPlaylist>? _playlists;
  final Set<String> _selected = {};
  bool _loading = false;
  bool _running = false;
  bool _cancelled = false;
  bool _reconnect = false;
  String? _current;
  int _done = 0;
  int _total = 0;
  final List<ImportResult> _results = [];

  List<ExternalPlaylist>? get playlists => _playlists;
  bool get loading => _loading;
  bool get running => _running;
  bool get needsReconnect => _reconnect;
  bool isSelected(String id) => _selected.contains(id);
  int get selectedCount => _selected.length;
  String? get current => _current;
  int get done => _done;
  int get total => _total;
  List<ImportResult> get results => List.unmodifiable(_results);

  String nameOf(ExternalPlaylist p) => p.liked ? _likedName : p.name;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _playlists = await _loadPlaylists();
      _reconnect = _needsReconnect();
    } catch (e) {
      _log.warning('loading playlists failed: $e');
      _playlists = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void toggle(String id) {
    if (_running) return;
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void cancel() {
    _cancelled = true;
    notifyListeners();
  }

  /// Imports the chosen playlists, one after the other.
  Future<void> run() async {
    final chosen = [for (final p in _playlists ?? const <ExternalPlaylist>[]) if (_selected.contains(p.id)) p];
    if (_running || chosen.isEmpty) return;
    _running = true;
    _cancelled = false;
    _results.clear();
    _done = 0;
    _total = chosen.fold(0, (n, p) => n + (p.total > Playlist.maxTracks ? Playlist.maxTracks : p.total));
    notifyListeners();
    try {
      for (final p in chosen) {
        if (_cancelled) break;
        _current = nameOf(p);
        notifyListeners();
        final refs = await _loadTracks(p);
        final found = <Track>[];
        for (final r in refs.take(Playlist.maxTracks)) {
          if (_cancelled) break;
          final t = await _matcher.match(r);
          if (t != null) found.add(t);
          _done++;
          notifyListeners();
          if (gap > Duration.zero) await Future<void>.delayed(gap);
        }
        String? id;
        if (found.isNotEmpty) id = (await _create(nameOf(p), found))?.id;
        _results.add(ImportResult(name: nameOf(p), found: found.length, total: refs.length, playlistId: id));
        notifyListeners();
      }
    } catch (e) {
      _log.warning('import failed: $e');
    } finally {
      _running = false;
      _current = null;
      _selected.clear();
      notifyListeners();
    }
  }
}
