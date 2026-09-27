abstract class SpotifyContract {
  bool get isConnected;
  bool get isPremium;
  String? get displayName;
  String? get activeDeviceName;
  String? get lastError;

  Future<void> loadSavedState();
  Future<bool> connect();
  Future<void> disconnect();
  Future<String?> getValidToken();
  Future<String?> searchTrack(String title, String artist);
  Future<bool> play({required String trackUri});
  Future<void> pause();
  Future<void> resume();
  Future<void> seekTo(int positionMs);
  Future<String?> ensureActiveDevice();
  Future<void> openSpotifyApp();
}
