import '../../models/track.dart';
import '../../models/artist.dart';

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
  Future<bool> hasCompletedOnboarding();
  Future<void> setCompletedOnboarding(bool completed);
  Future<String> getAppLanguage();
  Future<void> saveAppLanguage(String code);
  Future<int> getCrossfadeSeconds();
  Future<void> saveCrossfadeSeconds(int seconds);
  Future<Map<String, String>> getSpotifyUriCache();
  Future<void> saveSpotifyUriCache(Map<String, String> cache);
}

