import 'dart:collection';

import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../datasources/storage_service.dart';

/// The favorite songs and artists, kept on this phone only (not synced),
/// newest first. Asking whether something is a favorite is a set lookup:
/// song lists ask it once per row.
class FavoritesLocalStore {
  FavoritesLocalStore(this._storage, {required void Function() onChanged}) : _onChanged = onChanged;

  final StorageService _storage;
  final void Function() _onChanged;

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  Set<String> _trackIds = {};
  Set<String> _artistIds = {};

  // The same view until the list changes, so screens can compare it.
  List<Track>? _tracksView;
  List<Artist>? _artistsView;
  List<Track> get tracks => _tracksView ??= UnmodifiableListView(_tracks);
  List<Artist> get artists => _artistsView ??= UnmodifiableListView(_artists);

  bool isFavoriteTrack(String trackId) => _trackIds.contains(trackId);
  bool isFavoriteArtist(String artistId) => _artistIds.contains(artistId);

  /// Reads what's saved. Doesn't notify: the caller does once everything
  /// local is in.
  Future<void> load() async {
    _tracks = await _storage.getFavoriteTracks();
    _artists = await _storage.getFavoriteArtists();
    _trackIds = {for (final t in _tracks) t.id};
    _artistIds = {for (final a in _artists) a.id};
    _tracksView = null;
    _artistsView = null;
  }

  /// Adds [track] first, or removes it when it was a favorite.
  Future<void> toggleTrack(Track track) async {
    if (_trackIds.remove(track.id)) {
      _tracks = [for (final t in _tracks) if (t.id != track.id) t];
    } else {
      _trackIds.add(track.id);
      _tracks = [track, ..._tracks];
    }
    _tracksView = null;
    _onChanged();
    await _storage.saveFavoriteTracks(_tracks);
  }

  /// Adds [artist] first, or removes them when they were a favorite.
  Future<void> toggleArtist(Artist artist) async {
    if (_artistIds.remove(artist.id)) {
      _artists = [for (final a in _artists) if (a.id != artist.id) a];
    } else {
      _artistIds.add(artist.id);
      _artists = [artist, ..._artists];
    }
    _artistsView = null;
    _onChanged();
    await _storage.saveFavoriteArtists(_artists);
  }
}
