import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_language.dart';
import '../../core/localization/app_strings.dart';
import '../../core/logger.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import 'deezer_api_service.dart';
import 'media_session_handler.dart';
import 'storage_service.dart';


final _log = Log.named('Auto');

/// What Android Auto (and other media browsers) can browse and play.
///
/// Everything is read from storage and the API, never from the widget tree:
/// when the car starts the app there is no screen, so no providers are built.
/// Playing goes through [play], which the audio provider supplies.
class AutoMediaLibrary implements MediaLibrarySource {
  AutoMediaLibrary({
    required this.play,
    StorageService? storage,
    DeezerApiService? api,
    Future<String?> Function()? currentUid,
  })  : _storage = storage ?? StorageService(),
        _api = api ?? DeezerApiService(),
        _currentUid = currentUid ?? _defaultUid;

  /// Starts [track] with [queue] as the play queue.
  final Future<void> Function(Track track, List<Track> queue) play;
  final StorageService _storage;
  final DeezerApiService _api;
  final Future<String?> Function() _currentUid;

  // Not 'recent': that's Android Auto's own resume root.
  static const recentId = 'recents';
  static const favoritesId = 'fav';
  static const playlistsId = 'playlists';
  static const topId = 'top';
  static const _playlistPrefix = 'pl:';
  static const _searchPrefix = 'search:';
  // Separates a playable item's list from its track: "fav|123".
  static const _sep = '|';

  // The lists last shown, so a tap plays the same list as its queue.
  final Map<String, List<Track>> _lists = {};

  static Future<String?> _defaultUid() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ??
          await auth.authStateChanges().first.timeout(const Duration(seconds: 3));
      if (user != null) return user.uid;
    } catch (_) {}
    // Guests keep their playlists under a device id.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('guest_mode_active') == true) return prefs.getString('guest_device_uid');
    return null;
  }

  Future<AppStrings> _strings() async =>
      AppStrings(AppLanguage.fromCode(await _storage.getAppLanguage()));

  @override
  Future<List<MediaItem>> children(String parentId) async {
    try {
      switch (parentId) {
        case AudioService.browsableRootId:
          final s = await _strings();
          return [
            _folder(recentId, s.autoRecent),
            _folder(favoritesId, s.autoFavorites),
            _folder(playlistsId, s.autoPlaylists),
            _folder(topId, s.autoTopChart),
          ];
        // Android Auto asks for this to offer "resume" when it connects.
        case AudioService.recentRootId:
          final last = await _lastPlayed();
          return last == null ? const [] : _tracks(recentId, [last]);
        case recentId:
          return _tracks(recentId, await _storage.getRecentTracks());
        case favoritesId:
          return _tracks(favoritesId, await _storage.getFavoriteTracks());
        case topId:
          return _tracks(topId, await _api.getChartTracks());
        case playlistsId:
          final playlists = await _playlists();
          return [
            for (final p in playlists)
              if (p.tracks.isNotEmpty)
                _folder('$_playlistPrefix${p.id}', p.name,
                    subtitle: '${p.tracks.length}',
                    art: p.tracks.first.coverUrl),
          ];
      }
      if (parentId.startsWith(_playlistPrefix)) {
        final id = parentId.substring(_playlistPrefix.length);
        final playlist = (await _playlists()).where((p) => p.id == id).firstOrNull;
        return _tracks(parentId, playlist?.tracks ?? const []);
      }
    } catch (e) {
      _log.severe('browse "$parentId" failed: $e');
    }
    return const [];
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      return _tracks('$_searchPrefix$q', await _api.searchTracks(q));
    } catch (e) {
      _log.severe('search failed: $e');
      return const [];
    }
  }

  @override
  Future<void> playFromMediaId(String mediaId) async {
    final cut = mediaId.lastIndexOf(_sep);
    if (cut <= 0) return;
    final listId = mediaId.substring(0, cut);
    final trackId = mediaId.substring(cut + 1);
    // Rebuilt if the car kept an id from before the app restarted.
    var list = _lists[listId];
    if (list == null || !list.any((t) => t.id == trackId)) {
      if (listId.startsWith(_searchPrefix)) {
        await search(listId.substring(_searchPrefix.length));
      } else {
        await children(listId);
      }
      list = _lists[listId];
    }
    final track = list?.where((t) => t.id == trackId).firstOrNull;
    if (track != null) await play(track, list!);
  }

  /// "Play X on Tsuki Tunes": the first search hit, with the rest queued.
  /// No words ("play Tsuki Tunes"): the recent songs.
  @override
  Future<bool> playFromSearch(String query) async {
    final q = query.trim();
    final tracks = q.isEmpty ? await _storage.getRecentTracks() : await _api.searchTracks(q);
    final playable = tracks.where((t) => t.id.isNotEmpty).toList();
    if (playable.isEmpty) return false;
    await play(playable.first, playable);
    return true;
  }

  Future<Track?> _lastPlayed() async {
    final state = await _storage.getPlaybackState();
    final queue = state?['queue'];
    if (queue is List && queue.isNotEmpty) {
      final i = (state!['currentIndex'] as int? ?? 0).clamp(0, queue.length - 1);
      try {
        return Track.fromDeezer(Map<String, dynamic>.from(queue[i] as Map));
      } catch (_) {}
    }
    final recent = await _storage.getRecentTracks();
    return recent.isEmpty ? null : recent.first;
  }

  Future<List<Playlist>> _playlists() async {
    final uid = await _currentUid();
    if (uid == null) return const [];
    final cached = await _storage.getCachedPlaylists(uid);
    return cached.map(Playlist.fromJson).toList();
  }

  MediaItem _folder(String id, String title, {String? subtitle, String? art}) => MediaItem(
        id: id,
        title: title,
        displaySubtitle: subtitle,
        playable: false,
        artUri: art == null || art.isEmpty ? null : Uri.tryParse(art),
      );

  List<MediaItem> _tracks(String listId, List<Track> tracks) {
    final playable = tracks.where((t) => t.id.isNotEmpty).toList();
    _lists[listId] = playable;
    return playable.map((t) => MediaItem(
          id: '$listId$_sep${t.id}',
          title: t.title,
          artist: t.fullArtistName,
          album: t.albumTitle,
          duration: t.durationSeconds > 0 ? Duration(seconds: t.durationSeconds) : null,
          artUri: t.coverUrl.isEmpty ? null : Uri.tryParse(t.coverUrl),
          playable: true,
        )).toList();
  }
}
