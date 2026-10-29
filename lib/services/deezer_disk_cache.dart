import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/artist_albums_page.dart';
import '../models/track.dart';

dynamic _decodeJson(String source) => json.decode(source);
const int _isolateThreshold = 10 * 1024;

class DeezerDiskCache {
  static final DeezerDiskCache _instance = DeezerDiskCache._();
  factory DeezerDiskCache() => _instance;
  DeezerDiskCache._();

  Directory? _dir;
  bool _ready = false;
  static const int _maxEntries = 500;

  bool get isReady => _ready;

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      Directory base;
      try {
        base = await getApplicationCacheDirectory();
      } catch (_) {
        base = await getTemporaryDirectory();
      }
      _dir = Directory('${base.path}/deezer_api');
      if (!_dir!.existsSync()) {
        await _dir!.create(recursive: true);
      }
      _ready = true;
      unawaited(_pruneExpired());
    } catch (e) {
      debugPrint('[DeezerDiskCache] init failed: $e');
    }
  }

  String _hash(String key) => md5.convert(utf8.encode(key)).toString();

  Future<({String type, dynamic data, DateTime expiry})?> read(
      String key) async {
    if (!_ready) return null;
    try {
      final file = File('${_dir!.path}/${_hash(key)}.json');
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final decoded = content.length >= _isolateThreshold
          ? await compute(_decodeJson, content)
          : json.decode(content);
      final envelope = decoded as Map<String, dynamic>;
      final expiryMs = envelope['e'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
        file.delete().ignore();
        return null;
      }
      return (
        type: envelope['t'] as String,
        data: envelope['d'],
        expiry: DateTime.fromMillisecondsSinceEpoch(expiryMs),
      );
    } catch (e) {
      debugPrint('[DeezerDiskCache] read error ($key): $e');
      return null;
    }
  }

  void write(String key, String type, dynamic serialized, DateTime expiry) {
    if (!_ready) return;
    try {
      final envelope = {
        't': type,
        'e': expiry.millisecondsSinceEpoch,
        'd': serialized,
      };
      final file = File('${_dir!.path}/${_hash(key)}.json');
      unawaited(
        file.writeAsString(json.encode(envelope)).catchError((Object e) {
          debugPrint('[DeezerDiskCache] write error ($key): $e');
          return file;
        }),
      );
    } catch (e) {
      debugPrint('[DeezerDiskCache] write error ($key): $e');
    }
  }

  Future<void> clear() async {
    if (!_ready) return;
    try {
      final entries = _dir!.listSync();
      for (final entry in entries) {
        if (entry is File) await entry.delete().catchError((_) => entry);
      }
    } catch (e) {
      debugPrint('[DeezerDiskCache] clear error: $e');
    }
  }

  Future<void> _pruneExpired() async {
    if (!_ready) return;
    try {
      final files = _dir!.listSync().whereType<File>().toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      var removed = 0;

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final envelope = json.decode(content) as Map<String, dynamic>;
          if (envelope['e'] is int && now > (envelope['e'] as int)) {
            await file.delete();
            removed++;
          }
        } catch (_) {
          await file.delete().catchError((_) => file);
          removed++;
        }
      }

      final remaining = files.length - removed;
      if (remaining > _maxEntries) {
        final live = _dir!.listSync().whereType<File>().toList();
        live.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        final excess = live.length - _maxEntries;
        for (var i = 0; i < excess; i++) {
          await live[i].delete().catchError((_) => live[i]);
        }
        removed += excess;
      }

      if (removed > 0) {
        debugPrint('[DeezerDiskCache] pruned $removed expired entries');
      }
    } catch (e) {
      debugPrint('[DeezerDiskCache] prune error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  static String? typeTagFor(dynamic data) {
    if (data is ArtistAlbumsPage) return 'albums_page';
    if (data is Artist) return 'artist';
    if (data is Album) return 'album';
    if (data is Track) return 'track';
    if (data is List<Artist>) return 'artists';
    if (data is List<Album>) return 'albums';
    if (data is List<Track>) return 'tracks';
    if (data is Map<String, dynamic> && data.containsKey('artists')) {
      return 'search';
    }
    return null;
  }

  static dynamic serialize(String type, dynamic data) {
    switch (type) {
      case 'artist':
        return (data as Artist).toJson();
      case 'artists':
        return (data as List<Artist>).map((a) => a.toJson()).toList();
      case 'album':
        return (data as Album).toJson();
      case 'albums':
        return (data as List<Album>).map((a) => a.toJson()).toList();
      case 'track':
        return (data as Track).toJson();
      case 'tracks':
        return (data as List<Track>).map((t) => t.toJson()).toList();
      case 'albums_page':
        final page = data as ArtistAlbumsPage;
        return {
          'items': page.items.map((a) => a.toJson()).toList(),
          'total': page.total,
          'hasMore': page.hasMore,
          'nextIndex': page.nextIndex,
        };
      case 'search':
        final map = data as Map<String, dynamic>;
        return {
          'artists':
              (map['artists'] as List).map((a) => (a as Artist).toJson()).toList(),
          'albums':
              (map['albums'] as List).map((a) => (a as Album).toJson()).toList(),
          'tracks':
              (map['tracks'] as List).map((t) => (t as Track).toJson()).toList(),
        };
    }
    return null;
  }

  static dynamic deserialize(String type, dynamic raw) {
    switch (type) {
      case 'artist':
        return Artist.fromStorage(Map<String, dynamic>.from(raw as Map));
      case 'artists':
        return (raw as List)
            .map((e) => Artist.fromStorage(Map<String, dynamic>.from(e as Map)))
            .toList();
      case 'album':
        return Album.fromStorage(Map<String, dynamic>.from(raw as Map));
      case 'albums':
        return (raw as List)
            .map((e) => Album.fromStorage(Map<String, dynamic>.from(e as Map)))
            .toList();
      case 'track':
        return Track.fromStorage(Map<String, dynamic>.from(raw as Map));
      case 'tracks':
        return (raw as List)
            .map((e) => Track.fromStorage(Map<String, dynamic>.from(e as Map)))
            .toList();
      case 'albums_page':
        final map = Map<String, dynamic>.from(raw as Map);
        final items = (map['items'] as List)
            .map((e) => Album.fromStorage(Map<String, dynamic>.from(e as Map)))
            .toList();
        return ArtistAlbumsPage(
          items: items,
          total: map['total'] ?? 0,
          hasMore: map['hasMore'] ?? false,
          nextIndex: map['nextIndex'] ?? 0,
        );
      case 'search':
        final map = Map<String, dynamic>.from(raw as Map);
        return <String, dynamic>{
          'artists': (map['artists'] as List)
              .map(
                  (e) => Artist.fromStorage(Map<String, dynamic>.from(e as Map)))
              .toList(),
          'albums': (map['albums'] as List)
              .map(
                  (e) => Album.fromStorage(Map<String, dynamic>.from(e as Map)))
              .toList(),
          'tracks': (map['tracks'] as List)
              .map(
                  (e) => Track.fromStorage(Map<String, dynamic>.from(e as Map)))
              .toList(),
        };
    }
    return null;
  }
}
