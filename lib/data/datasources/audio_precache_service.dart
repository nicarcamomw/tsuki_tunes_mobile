import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/logger.dart';
import '../../domain/entities/track.dart';
import 'album_downloads.dart';


final _log = Log.named('AudioPrecache');

/// Service responsible for predictive background caching of audio previews.
/// Pre-downloads upcoming tracks in queue to eliminate network buffer latency
/// enabling zero-latency gapless playback.
class AudioPrecacheService {
  static final AudioPrecacheService _instance = AudioPrecacheService._internal();
  factory AudioPrecacheService() => _instance;
  AudioPrecacheService._internal();

  final Map<String, String> _cachedPaths = {};
  final Set<String> _inFlight = {};
  // The next songs downloaded ahead plus the last ones played (~0.5 MB each).
  static const int _maxCachedFiles = 25;
  // And never more than this on disk, whatever the previews weigh.
  static const int _defaultMaxCacheBytes = 20 * 1024 * 1024;
  static int _maxCacheBytes = _defaultMaxCacheBytes;
  final List<String> _cacheLruOrder = [];

  bool _diskIndexed = false;

  static const String _folderName = 'tsuki_preview_cache';

  /// The app's cache folder, once [init] found it; until then (and if it
  /// fails) the system temp folder, which on Android is that same folder.
  Directory? _resolvedDir;
  bool _initStarted = false;

  Directory get _legacyDir => Directory('${Directory.systemTemp.path}/$_folderName');

  /// Finds the app's cache folder (getApplicationCacheDirectory) and moves
  /// there the previews kept in the system temp folder by earlier versions.
  /// On Android both are the same folder, so nothing moves and nothing is
  /// forgotten. Lookups never wait for this: they use the temp folder
  /// until it's done.
  Future<void> init({
    @visibleForTesting Future<Directory> Function()? cacheBase,
    @visibleForTesting Directory? legacyDir,
  }) async {
    if (kIsWeb || _initStarted) return;
    _initStarted = true;
    try {
      final base = await (cacheBase ?? getApplicationCacheDirectory)();
      final dir = Directory('${base.path}/$_folderName');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final legacy = legacyDir ?? _legacyDir;
      if (_samePath(dir, legacy)) {
        _resolvedDir = dir;
        return;
      }
      if (legacy.existsSync()) _moveFiles(legacy, dir);
      _resolvedDir = dir;
      // Paths in memory pointed at the old folder: index the new one.
      _cachedPaths.clear();
      _cacheLruOrder.clear();
      _diskIndexed = false;
    } catch (e) {
      _log.warning('cache folder lookup failed, keeping the temp folder: $e');
    }
  }

  static bool _samePath(Directory a, Directory b) {
    try {
      return a.resolveSymbolicLinksSync() == b.resolveSymbolicLinksSync();
    } catch (_) {
      return a.absolute.path == b.absolute.path;
    }
  }

  /// Moves the previews from [from] to [to] (a copy already there wins),
  /// then removes [from] once it's empty.
  void _moveFiles(Directory from, Directory to) {
    var moved = 0;
    for (final entity in from.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final target = File('${to.path}/$name');
      try {
        if (target.existsSync()) {
          entity.deleteSync();
          continue;
        }
        try {
          entity.renameSync(target.path);
        } on FileSystemException {
          // Another disk: copy, then delete.
          entity.copySync(target.path);
          entity.deleteSync();
        }
        moved++;
      } catch (e) {
        _log.warning('could not move $name: $e');
      }
    }
    try {
      if (from.listSync().isEmpty) from.deleteSync();
    } catch (_) {}
    if (moved > 0) _log.info('moved $moved previews to the app cache folder');
  }

  /// Tests run in parallel: each can keep its previews in its own folder.
  static Directory? _dirOverride;
  @visibleForTesting
  static set cacheDirForTesting(Directory? dir) {
    _dirOverride = dir;
    _instance.forgetInMemoryForTesting();
  }

  Directory? _getCacheDir() {
    try {
      final dir = _dirOverride ?? _resolvedDir ?? _legacyDir;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      if (!_diskIndexed) {
        _diskIndexed = true;
        _indexExistingFiles(dir);
      }
      return dir;
    } catch (e) {
      _log.severe('error getting cache dir: $e');
      return null;
    }
  }

  /// Files from previous sessions are not in the in-memory LRU, so they were
  /// never pruned. Load them oldest-first and trim to the limit.
  void _indexExistingFiles(Directory dir) {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'))
          .toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        if (!name.startsWith('preview_')) continue;
        final id = name.substring('preview_'.length, name.length - '.mp3'.length);
        _cachedPaths[id] = file.path;
        _cacheLruOrder.remove(id);
        _cacheLruOrder.add(id);
      }
      _pruneOldFiles();
    } catch (e) {
      _log.severe('error indexing cache dir: $e');
    }
  }

  void _touch(String trackId) {
    _cacheLruOrder.remove(trackId);
    _cacheLruOrder.add(trackId);
  }

  /// Checks if track is already cached locally with a valid non-empty file.
  String? getCachedFilePath(String trackId) {
    // A song of a downloaded album: kept apart, never pruned.
    final saved = AlbumDownloads.instance.pathFor(trackId);
    if (saved != null) return saved;
    final cached = _cachedPaths[trackId];
    if (cached != null) {
      final file = File(cached);
      if (file.existsSync() && file.lengthSync() > 10000) {
        _touch(trackId);
        return cached;
      }
      _cachedPaths.remove(trackId);
      _cacheLruOrder.remove(trackId);
    }

    // Check disk directly in case app was restarted
    final dir = _getCacheDir();
    if (dir != null) {
      final file = File('${dir.path}/preview_$trackId.mp3');
      if (file.existsSync() && file.lengthSync() > 10000) {
        _cachedPaths[trackId] = file.path;
        _touch(trackId);
        return file.path;
      }
    }
    return null;
  }

  /// Answers that say the preview link itself is no good (expired or
  /// revoked signature), not the network: a fresh link may work.
  static const _staleLinkStatuses = {401, 403, 410};

  /// Silently pre-downloads the ~450KB preview of an upcoming track in the background.
  ///
  /// When Deezer refuses the link (its signature expired or was revoked
  /// early), [onStale] is asked once for the same track with a fresh link,
  /// and the download is tried again with it.
  Future<void> precacheTrack(Track track,
      {Future<Track?> Function(Track track)? onStale}) async {
    if (kIsWeb) return;
    if (track.previewUrl.isEmpty) return;
    if (getCachedFilePath(track.id) != null) return;
    if (_inFlight.contains(track.id)) return;

    _inFlight.add(track.id);

    try {
      final dir = _getCacheDir();
      if (dir == null) return;

      final targetFile = File('${dir.path}/preview_${track.id}.mp3');
      _log.fine('Pre-caching upcoming track audio: "${track.title}"...');

      var response = await http
          .get(Uri.parse(track.previewUrl))
          .timeout(const Duration(seconds: 12));

      if (_staleLinkStatuses.contains(response.statusCode) && onStale != null) {
        final fresh = await onStale(track);
        if (fresh != null &&
            fresh.previewUrl.isNotEmpty &&
            fresh.previewUrl != track.previewUrl) {
          _log.info('Preview link of "${track.title}" was refused: retrying with a fresh one');
          response = await http
              .get(Uri.parse(fresh.previewUrl))
              .timeout(const Duration(seconds: 12));
        }
      }

      if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
        await targetFile.writeAsBytes(response.bodyBytes, flush: true);
        _cachedPaths[track.id] = targetFile.path;
        _touch(track.id);
        _pruneOldFiles();
        _log.info('Pre-cached "${track.title}" (${response.bodyBytes.length} bytes) successfully! Zero-latency ready.');
      }
    } catch (e) {
      _log.warning('Non-fatal precache error for "${track.title}": $e');
    } finally {
      _inFlight.remove(track.id);
    }
  }

  /// Drops the least recently used previews while there are more than
  /// [_maxCachedFiles] or they weigh more than [_maxCacheBytes]. The most
  /// recent one always stays.
  void _pruneOldFiles() {
    var total = 0;
    for (final id in _cacheLruOrder) {
      total += _sizeOf(_cachedPaths[id]);
    }
    while (_cacheLruOrder.length > _maxCachedFiles ||
        (_cacheLruOrder.length > 1 && total > _maxCacheBytes)) {
      final oldestId = _cacheLruOrder.removeAt(0);
      final path = _cachedPaths.remove(oldestId);
      if (path != null) {
        total -= _sizeOf(path);
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
  }

  static int _sizeOf(String? path) {
    if (path == null) return 0;
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  @visibleForTesting
  static set maxCacheBytesForTesting(int? bytes) =>
      _maxCacheBytes = bytes ?? _defaultMaxCacheBytes;

  /// Forgets what's in memory, leaving the files: like the app starting
  /// again with the previous sessions' previews on disk.
  @visibleForTesting
  void forgetInMemoryForTesting() {
    _cachedPaths.clear();
    _cacheLruOrder.clear();
    _diskIndexed = false;
  }

  @visibleForTesting
  void resetInitForTesting() {
    _initStarted = false;
    _resolvedDir = null;
  }

  void clearCache() {
    _cachedPaths.clear();
    _cacheLruOrder.clear();
    try {
      final dir = _getCacheDir();
      if (dir != null && dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}
