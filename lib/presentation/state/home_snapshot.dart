import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';

final _log = Log.named('HomeSnapshot');

/// The last home the network gave (I-01): shown at once on the next start
/// while a fresh one loads behind it, instead of a skeleton every time.
///
/// Only the catalog's part is kept (featured artists, the pictures of the
/// top artists by name, the latest releases); the library's own figures
/// are local and always current.
class HomeSnapshot {
  const HomeSnapshot({required this.featured, required this.topArtists, required this.releases});

  final List<Artist> featured;

  /// Top artists' catalog entries by the name the library knows them by.
  final Map<String, Artist> topArtists;
  final List<Album> releases;

  bool get isEmpty => featured.isEmpty && topArtists.isEmpty && releases.isEmpty;

  static const _key = 'home_snapshot_v1';

  static Future<HomeSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return HomeSnapshot(
        featured: [
          for (final a in json['featured'] as List? ?? const []) Artist.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
        topArtists: {
          for (final e in (json['top'] as Map? ?? const {}).entries)
            e.key as String: Artist.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        releases: [
          for (final a in json['releases'] as List? ?? const []) Album.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
      );
    } catch (e) {
      // A snapshot from an older shape is just dropped.
      _log.warning('unreadable home snapshot: $e');
      return null;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'featured': [for (final a in featured.take(10)) a.toJson()],
          'top': {for (final e in topArtists.entries) e.key: e.value.toJson()},
          // Covers and titles are enough to show; the album opens fresh.
          'releases': [for (final a in releases.take(12)) a.copyWith(tracks: const []).toJson()],
        }),
      );
    } catch (e) {
      _log.warning('home snapshot not saved: $e');
    }
  }
}
