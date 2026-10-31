import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';

abstract class StorageContract {
  Future<List<Track>> getFavoriteTracks();
  Future<void> saveFavoriteTracks(List<Track> tracks);
  Future<List<Track>> getRecentTracks();
  Future<void> saveRecentTracks(List<Track> tracks);
  Future<List<Artist>> getFavoriteArtists();
  Future<void> saveFavoriteArtists(List<Artist> artists);
  Future<Map<String, int>> getArtistVisits();
  Future<void> saveArtistVisits(Map<String, int> visits);
  Future<Map<String, int>> getAlbumTrackCounts();
  Future<void> saveAlbumTrackCounts(Map<String, int> counts);
  Future<List<Map<String, dynamic>>> getCachedListenedTracks(String uid);
  Future<void> saveCachedListenedTracks(String uid, List<Map<String, dynamic>> tracks);
  Future<DateTime?> getLastListenedFullSync(String uid);
  Future<void> saveLastListenedFullSync(String uid, DateTime time);
  Future<bool> hasCompletedOnboarding();
  Future<void> setCompletedOnboarding(bool completed);
  Future<String> getAppLanguage();
  Future<void> saveAppLanguage(String code);
  Future<int> getCrossfadeSeconds();
  Future<void> saveCrossfadeSeconds(int seconds);
  Future<bool> getAutoMarkListened();
  Future<void> saveAutoMarkListened(bool enabled);
  Future<bool> getPrecacheWifiOnly();
  Future<void> savePrecacheWifiOnly(bool enabled);
  Future<Map<String, String>> getSpotifyUriCache();
  Future<void> saveSpotifyUriCache(Map<String, String> cache);
  Future<Map<String, dynamic>?> getPlaybackState();
  Future<void> savePlaybackState(List<Track>? queue,
      [int? currentIndex,
      int? positionMs,
      bool? wasPlaying,
      Map<String, dynamic>? radio]);
  Future<List<Map<String, dynamic>>> getCachedPlaylists(String uid);
  Future<void> saveCachedPlaylists(String uid, List<Map<String, dynamic>> playlists);
  Future<List<Map<String, dynamic>>> getCachedFollowedArtists(String uid);
  Future<void> saveCachedFollowedArtists(String uid, List<Map<String, dynamic>> artists);
  Future<String?> getBirthday();
  Future<void> saveBirthday(String? birthday);
}

