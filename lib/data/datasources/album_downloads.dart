import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/logger.dart';
import '../../domain/entities/album.dart';

final _log = Log.named('AlbumDownloads');

/// Albums saved for listening without internet: each song's 30-second
/// preview (all the licence allows), kept until the user removes it, apart
/// from the cache of upcoming songs that rotates on its own. The album
/// itself (title, cover, songs) is kept too, so it opens offline.
class AlbumDownloads {
  AlbumDownloads._();
  static final AlbumDownloads instance = AlbumDownloads._();

  /// Where the files go; tests point it at a temporary folder.
  @visibleForTesting
  static Future<Directory> Function() baseDir = getApplicationSupportDirectory;

  Directory? _dir;
  // albumId -> the album's JSON (with its songs).
  final Map<String, Map<String, dynamic>> _albums = {};
  // trackId -> file path, for every saved song.
  final Map<String, String> _files = {};
  Future<void>? _ready;

  Future<void> ready() => _ready ??= _load();

  Future<void> _load() async {
    if (kIsWeb) return;
    try {
      final base = await baseDir();
      final dir = Directory('${base.path}/tsuki_downloads');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _dir = dir;
      final index = File('${dir.path}/index.json');
      if (index.existsSync()) {
        final data = jsonDecode(await index.readAsString());
        if (data is Map) {
          data.forEach((id, album) {
            if (album is Map) _albums[id as String] = Map<String, dynamic>.from(album);
          });
        }
      }
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('preview_') && name.endsWith('.mp3')) {
          _files[name.substring(8, name.length - 4)] = f.path;
        }
      }
    } catch (e) {
      _log.severe('loading downloads failed: $e');
    }
  }

  /// The saved preview of [trackId], if any. Synchronous, for the player;
  /// null until [ready] has run once.
  String? pathFor(String trackId) {
    final p = _files[trackId];
    if (p == null) return null;
    if (File(p).existsSync()) return p;
    _files.remove(trackId);
    return null;
  }

  bool isDownloaded(String albumId) => _albums.containsKey(albumId);

  Iterable<String> get albumIds => _albums.keys;

  /// The saved album, with its songs, to open it offline.
  Album? album(String albumId) {
    final json = _albums[albumId];
    if (json == null) return null;
    try {
      return Album.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Disk used by the saved songs, in bytes.
  int get bytes {
    var total = 0;
    for (final p in _files.values) {
      try {
        total += File(p).lengthSync();
      } catch (_) {}
    }
    return total;
  }

  /// Saves the previews of [album]'s songs (with their links fresh from the
  /// catalog: Deezer's expire). Calls [onProgress] after each song. True
  /// when every song with a preview was saved; songs already saved (by
  /// another album) are not downloaded again.
  Future<bool> download(Album album, {void Function(int done, int total)? onProgress}) async {
    await ready();
    final dir = _dir;
    if (dir == null) return false;
    final songs = [for (final t in album.tracks) if (t.previewUrl.isNotEmpty) t];
    if (songs.isEmpty) return false;
    var done = 0;
    var failed = 0;
    for (final t in songs) {
      if (pathFor(t.id) == null) {
        try {
          final res = await http.get(Uri.parse(t.previewUrl)).timeout(const Duration(seconds: 20));
          if (res.statusCode == 200 && res.bodyBytes.length > 10000) {
            final file = File('${dir.path}/preview_${t.id}.mp3');
            await file.writeAsBytes(res.bodyBytes, flush: true);
            _files[t.id] = file.path;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
          _log.warning('saving "${t.title}" failed: $e');
        }
      }
      onProgress?.call(++done, songs.length);
    }
    // Kept even if some failed: what was saved plays, the rest streams.
    _albums[album.id] = album.toJson();
    await _saveIndex();
    return failed == 0;
  }

  /// Removes [albumId] and the songs no other saved album has.
  Future<void> remove(String albumId) async {
    await ready();
    final json = _albums.remove(albumId);
    if (json == null) return;
    final kept = {
      for (final a in _albums.values)
        for (final t in (a['tracks'] as List? ?? const []))
          if (t is Map) '${t['id']}',
    };
    final removed = Album.fromJson(json).tracks.map((t) => t.id);
    for (final id in removed) {
      if (kept.contains(id)) continue;
      final p = _files.remove(id);
      if (p != null) {
        try {
          File(p).deleteSync();
        } catch (_) {}
      }
    }
    await _saveIndex();
  }

  Future<void> _saveIndex() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      await File('${dir.path}/index.json').writeAsString(jsonEncode(_albums), flush: true);
    } catch (e) {
      _log.severe('saving the downloads index failed: $e');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _dir = null;
    _albums.clear();
    _files.clear();
    _ready = null;
  }
}
