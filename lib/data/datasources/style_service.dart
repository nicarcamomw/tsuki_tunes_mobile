import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/artist_names.dart';
import '../../domain/logic/music_styles.dart';
import 'deezer_api_service.dart';
import 'lastfm_service.dart';

final _log = Log.named('Styles');

/// The music style of what's played, for the masks: the artist's tags on
/// Last.fm, or, when Last.fm doesn't know the artist, the genres Deezer
/// gives the album.
///
/// Looked up once per artist and kept on the phone ([maxArtists] of them);
/// an artist with no tags anywhere is asked again after [retryEmptyAfter].
class StyleService {
  StyleService({
    Future<List<String>> Function(String artist)? artistTags,
    Future<Album?> Function(String albumId)? album,
    DateTime Function()? clock,
  })  : _artistTags = artistTags ?? LastFmService.getArtistTags,
        _album = album ?? ((id) => DeezerApiService().getAlbum(id)),
        _clock = clock ?? DateTime.now;

  static final StyleService shared = StyleService();

  static const _cacheKey = 'artist_styles_v1';
  static const int maxArtists = 2000;
  static const Duration retryEmptyAfter = Duration(days: 30);

  final Future<List<String>> Function(String artist) _artistTags;
  final Future<Album?> Function(String albumId) _album;
  final DateTime Function() _clock;

  Map<String, _Entry>? _cache;
  final Map<String, Future<StyleInfo>> _inFlight = {};

  static String _key(String artistName) => ArtistNames.primary(artistName).toLowerCase();

  /// [track]'s style: its artist's, looked up the first time.
  Future<StyleInfo> styleOf(Track track) {
    final key = _key(track.artistName);
    if (key.isEmpty) return Future.value(StyleInfo.empty);
    // A block, not an arrow: remove() returns this same future, and
    // whenComplete would wait on it forever.
    return _inFlight[key] ??= _styleOf(key, track).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<StyleInfo> _styleOf(String key, Track track) async {
    final cache = await _load();
    final now = _clock();
    final known = cache[key];
    if (known != null && (!known.info.isEmpty || now.difference(known.at) < retryEmptyAfter)) {
      return known.info;
    }

    var info = StyleInfo.empty;
    try {
      info = MusicStyles.fromTags(await _artistTags(ArtistNames.primary(track.artistName)));
    } catch (e) {
      _log.fine('tags failed for $key: $e');
    }
    if (info.styles.isEmpty && track.albumId.isNotEmpty) {
      try {
        final album = await _album(track.albumId);
        final fromAlbum = MusicStyles.fromTags(album?.genres ?? const []);
        info = StyleInfo(styles: fromAlbum.styles, countries: {...info.countries, ...fromAlbum.countries});
      } catch (e) {
        _log.fine('album genres failed for $key: $e');
      }
    }
    cache.remove(key);
    cache[key] = _Entry(info, now);
    while (cache.length > maxArtists) {
      cache.remove(cache.keys.first);
    }
    unawaited(_save());
    return info;
  }

  Future<Map<String, _Entry>> _load() async {
    final loaded = _cache;
    if (loaded != null) return loaded;
    final cache = <String, _Entry>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          if (v is Map) cache[k] = _Entry.fromJson(v);
        });
      }
    } catch (e) {
      _log.warning('cache unreadable: $e');
    }
    return _cache ??= cache;
  }

  Future<void> _save() async {
    final cache = _cache;
    if (cache == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({for (final e in cache.entries) e.key: e.value.toJson()}));
    } catch (e) {
      _log.warning('cache not saved: $e');
    }
  }

  /// Forgets every artist (account deletion).
  Future<void> clear() async {
    _cache = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}

class _Entry {
  final StyleInfo info;
  final DateTime at;
  const _Entry(this.info, this.at);

  Map<String, Object> toJson() => {
        's': [for (final s in info.styles) s.name],
        'c': info.countries.toList(),
        'd': at.millisecondsSinceEpoch ~/ 86400000,
      };

  factory _Entry.fromJson(Map<dynamic, dynamic> m) => _Entry(
        StyleInfo(
          styles: {
            for (final n in (m['s'] as List? ?? const []))
              if (MusicStyles.byName('$n') case final s?) s,
          },
          countries: {for (final c in (m['c'] as List? ?? const [])) '$c'},
        ),
        DateTime.fromMillisecondsSinceEpoch(((m['d'] as num?)?.toInt() ?? 0) * 86400000),
      );
}
