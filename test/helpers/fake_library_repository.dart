import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/library_repository.dart';

/// In-memory library for use case tests; records the album counts it gets.
class FakeLibraryRepository implements LibraryRepository {
  final listened = <String>{};
  final followed = <String>{};
  final favoriteTracks = <String>{};
  final favoriteArtists = <String>{};
  final albumCounts = <String, int>{};
  final recent = <Track>[];
  final plays = <Track>[];

  /// Songs written by each mark call, to check nothing is written twice.
  final markCalls = <List<String>>[];

  @override
  bool isTrackListened(String trackId) => listened.contains(trackId);

  @override
  Future<void> markTrack(Track track) async {
    markCalls.add([track.id]);
    listened.add(track.id);
  }

  @override
  Future<void> unmarkTrack(String trackId) async => listened.remove(trackId);

  @override
  Future<void> markAlbumTracks(List<Track> tracks, {String? albumId, int? totalTracks}) async {
    if (albumId != null && totalTracks != null) albumCounts[albumId] = totalTracks;
    markCalls.add([for (final t in tracks) t.id]);
    listened.addAll(tracks.map((t) => t.id));
  }

  @override
  Future<void> unmarkAlbumTracks(List<String> trackIds) async => listened.removeAll(trackIds);

  @override
  void registerAlbumTrackCount(String albumId, int count) => albumCounts[albumId] = count;

  @override
  int getAlbumTracksCount(String albumId) => albumCounts[albumId] ?? 0;

  @override
  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0}) => false;

  @override
  bool isFavoriteTrack(String trackId) => favoriteTracks.contains(trackId);

  @override
  Future<void> toggleFavoriteTrack(Track track) async =>
      favoriteTracks.remove(track.id) || favoriteTracks.add(track.id);

  @override
  bool isFavoriteArtist(String artistId) => favoriteArtists.contains(artistId);

  @override
  Future<void> toggleFavoriteArtist(Artist artist) async =>
      favoriteArtists.remove(artist.id) || favoriteArtists.add(artist.id);

  @override
  bool isArtistFollowed(String artistId) => followed.contains(artistId);

  @override
  Future<void> followArtist(Artist artist) async => followed.add(artist.id);

  @override
  Future<void> unfollowArtist(String artistId) async => followed.remove(artistId);

  @override
  Future<void> addRecentTrack(Track track) async => recent.insert(0, track);

  @override
  Future<void> recordPlay(Track track) async => plays.add(track);
}
