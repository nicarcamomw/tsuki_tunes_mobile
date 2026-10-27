import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ApiDiskCache {
  static final ApiDiskCache _instance = ApiDiskCache._();
  factory ApiDiskCache() => _instance;
  ApiDiskCache._();

  Directory? _dir;
  bool _pruning = false;
  static const int _maxFiles = 500;

  Future<void> init() async {
    if (kIsWeb || _dir != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/deezer_cache');
      if (!_dir!.existsSync()) {
        _dir!.createSync(recursive: true);
      }
    } catch (e) {
      debugPrint('[ApiDiskCache] init error: $e');
    }
  }

  String _fileName(String key) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(key)) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toUnsigned(64).toRadixString(36);
  }

  File? _file(String key) {
    if (_dir == null) return null;
    return File('${_dir!.path}/${_fileName(key)}.json');
  }

  Future<dynamic> get(String key) async {
    final f = _file(key);
    if (f == null || !f.existsSync()) return null;
    try {
      final raw = await f.readAsString();
      final map = json.decode(raw) as Map<String, dynamic>;
      final expiry = DateTime.fromMillisecondsSinceEpoch(map['e'] as int);
      if (DateTime.now().isAfter(expiry)) return null;
      return map['d'];
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> getStale(String key) async {
    final f = _file(key);
    if (f == null || !f.existsSync()) return null;
    try {
      final raw = await f.readAsString();
      final map = json.decode(raw) as Map<String, dynamic>;
      return map['d'];
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, dynamic data, Duration ttl) async {
    final f = _file(key);
    if (f == null) return;
    try {
      final expiry = DateTime.now().add(ttl);
      final payload = json.encode({'e': expiry.millisecondsSinceEpoch, 'd': data});
      await f.writeAsString(payload);
      _pruneIfNeeded();
    } catch (e) {
      debugPrint('[ApiDiskCache] write error: $e');
    }
  }

  Future<void> clear() async {
    if (_dir == null) return;
    try {
      if (_dir!.existsSync()) {
        await _dir!.delete(recursive: true);
        _dir!.createSync(recursive: true);
      }
    } catch (_) {}
  }

  void _pruneIfNeeded() {
    if (_pruning || _dir == null) return;
    _pruning = true;
    compute(_pruneIsolate, _dir!.path).then((_) => _pruning = false,
        onError: (_) => _pruning = false);
  }

  static void _pruneIsolate(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList();
      if (files.length <= _maxFiles) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      final removeCount = files.length - (_maxFiles * 0.7).round();
      for (var i = 0; i < removeCount; i++) {
        files[i].deleteSync();
      }
    } catch (_) {}
  }
}
