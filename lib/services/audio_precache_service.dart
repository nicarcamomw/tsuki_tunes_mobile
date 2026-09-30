import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Service responsible for predictive background caching of audio previews.
/// Pre-downloads upcoming tracks in queue to eliminate network buffer latency
/// enabling zero-latency gapless playback.
class AudioPrecacheService {
  static final AudioPrecacheService _instance = AudioPrecacheService._internal();
  factory AudioPrecacheService() => _instance;
  AudioPrecacheService._internal();

  final Map<String, String> _cachedPaths = {};
  final Set<String> _inFlight = {};
  static const int _maxCachedFiles = 10;
  final List<String> _cacheLruOrder = [];

  Directory? _getCacheDir() {
    try {
      final dir = Directory('${Directory.systemTemp.path}/tsuki_preview_cache');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('[AudioPrecacheService] error getting cache dir: $e');
      return null;
    }
  }

  /// Checks if track is already cached locally with a valid non-empty file.
  String? getCachedFilePath(String trackId) {
    final cached = _cachedPaths[trackId];
    if (cached != null) {
      final file = File(cached);
      if (file.existsSync() && file.lengthSync() > 10000) {
        return cached;
      }
      _cachedPaths.remove(trackId);
    }

    // Check disk directly in case app was restarted
    final dir = _getCacheDir();
    if (dir != null) {
      final file = File('${dir.path}/preview_$trackId.mp3');
      if (file.existsSync() && file.lengthSync() > 10000) {
        _cachedPaths[trackId] = file.path;
        return file.path;
      }
    }
    return null;
  }

  /// Silently pre-downloads the ~450KB preview of the next track in the background.
  Future<void> precacheTrack(Track track) async {
    if (kIsWeb) return;
    if (track.previewUrl.isEmpty) return;
    if (getCachedFilePath(track.id) != null) return;
    if (_inFlight.contains(track.id)) return;

    _inFlight.add(track.id);

    try {
      final dir = _getCacheDir();
      if (dir == null) return;

      final targetFile = File('${dir.path}/preview_${track.id}.mp3');
      debugPrint('[AudioPrecache] Pre-caching next track audio: "${track.title}"...');

      final response = await http
          .get(Uri.parse(track.previewUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
        await targetFile.writeAsBytes(response.bodyBytes, flush: true);
        _cachedPaths[track.id] = targetFile.path;
        _cacheLruOrder.remove(track.id);
        _cacheLruOrder.add(track.id);
        _pruneOldFiles();
        debugPrint('[AudioPrecache] Pre-cached "${track.title}" (${response.bodyBytes.length} bytes) successfully! Zero-latency ready.');
      }
    } catch (e) {
      debugPrint('[AudioPrecache] Non-fatal precache error for "${track.title}": $e');
    } finally {
      _inFlight.remove(track.id);
    }
  }

  void _pruneOldFiles() {
    while (_cacheLruOrder.length > _maxCachedFiles) {
      final oldestId = _cacheLruOrder.removeAt(0);
      final path = _cachedPaths.remove(oldestId);
      if (path != null) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
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
