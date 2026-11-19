import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';

final _log = Log.named('BlobStore');

/// Large text kept in a file of its own in the app's support folder
/// instead of SharedPreferences (perf).
///
/// Android keeps every SharedPreferences value in one XML file and writes
/// all of it again on each change, anywhere in the app. The play history
/// and the saved queue (up to thousands of songs, a megabyte or more each)
/// made every small setting, and the position saved every few seconds
/// while a song plays, a rewrite of megabytes. A file here is written
/// alone, off the UI thread, and only when it changes.
///
/// [key] names both the file and the SharedPreferences key the value lived
/// under before: a value still there is read once, moved here and removed
/// there. Without a folder (web, tests without path_provider) it stays in
/// SharedPreferences, as before.
abstract final class BlobStore {
  /// Where the files go; null keeps values in SharedPreferences.
  @visibleForTesting
  static Future<Directory?> Function() directory = _supportDirectory;

  static Future<Directory?> _supportDirectory() async {
    if (kIsWeb) return null;
    // Under flutter test there's no path_provider, and inside a widget
    // test's fake clock its unanswered call would never end.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null; // No path provider (tests).
    }
  }

  static Future<File?> _file(String key) async {
    final dir = await directory();
    if (dir == null) return null;
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/blob_$safe.json');
  }

  /// The text under [key], or null.
  static Future<String?> read(String key) async {
    final file = await _file(key);
    final prefs = await SharedPreferences.getInstance();
    if (file == null) return prefs.getString(key);
    try {
      if (await file.exists()) return await file.readAsString();
    } catch (e) {
      _log.warning('reading $key failed: $e');
    }
    // Still where it was kept before: moved here once.
    final legacy = prefs.getString(key);
    if (legacy != null) {
      try {
        await _writeFile(file, legacy);
        await prefs.remove(key);
      } catch (e) {
        _log.warning('moving $key out of the preferences failed: $e');
      }
    }
    return legacy;
  }

  /// Writes of each key, in turn: two saves close together never write
  /// the same file at once, and the later one lands last.
  static final Map<String, Future<void>> _queue = {};

  /// Keeps [value] under [key].
  static Future<void> write(String key, String value) {
    final done = (_queue[key] ?? Future<void>.value()).then((_) async {
      final file = await _file(key);
      if (file == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
        return;
      }
      await _writeFile(file, value);
    });
    final next = done.catchError((Object e) => _log.warning('writing $key failed: $e'));
    _queue[key] = next;
    unawaited(next.whenComplete(() {
      if (identical(_queue[key], next)) _queue.remove(key);
    }));
    return done;
  }

  /// Forgets what's under [key], wherever it is.
  static Future<void> delete(String key) async {
    // After a write still under way, or it would bring the value back.
    await _queue[key];
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) await prefs.remove(key);
    try {
      final file = await _file(key);
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      _log.warning('removing $key failed: $e');
    }
  }

  /// Written beside, then moved over: a crash mid-write leaves the old file
  /// whole, never half of the new one.
  static Future<void> _writeFile(File file, String value) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(file.path);
  }
}
