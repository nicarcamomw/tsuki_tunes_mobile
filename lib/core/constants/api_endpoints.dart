class ApiEndpoints {
  static const String deezerBase = 'https://api.deezer.com';

  // Separate search endpoints (like web)
  static String search(String query, {int limit = 30}) =>
      '$deezerBase/search?q=${Uri.encodeComponent(query)}&limit=$limit';

  static String searchArtists(String query, {int limit = 25}) =>
      '$deezerBase/search/artist?q=${Uri.encodeComponent(query)}&limit=$limit';

  static String searchAlbums(String query, {int limit = 10}) =>
      '$deezerBase/search/album?q=${Uri.encodeComponent(query)}&limit=$limit';

  static String searchTracks(String query, {int limit = 25}) =>
      '$deezerBase/search/track?q=${Uri.encodeComponent(query)}&limit=$limit';

  // Charts
  static const String chartTracks = '$deezerBase/chart/0/tracks?limit=25';
  static const String chartArtists = '$deezerBase/chart/0/artists?limit=15';
  static const String chartAlbums = '$deezerBase/chart/0/albums?limit=15';

  // Entity endpoints
  static String artist(String id) => '$deezerBase/artist/$id';
  static String artistTopTracks(String id, {int limit = 10}) =>
      '$deezerBase/artist/$id/top?limit=$limit';
  static String artistAlbums(String id, {int limit = 250, int index = 0}) =>
      '$deezerBase/artist/$id/albums?limit=$limit&index=$index';
  static String artistCompilations(String id, {int limit = 50, int index = 0}) =>
      '$deezerBase/artist/$id/albums?type=compile&limit=$limit&index=$index';
  static String artistRelated(String id, {int limit = 20}) =>
      '$deezerBase/artist/$id/related?limit=$limit';
  static String album(String id) => '$deezerBase/album/$id';
  static String track(String id) => '$deezerBase/track/$id';

  // Default curated artist IDs from Tsuki Tunes
  static const List<String> featuredArtistIds = [
    '384236',   // Ed Sheeran
    '4050205',  // The Weeknd
    '12246',    // Taylor Swift
    '246791',   // Drake
    '8623912',  // Ariana Grande
    '119',      // Daft Punk
    '10874',    // Eminem
    '1429862',  // Travis Scott
  ];
}
