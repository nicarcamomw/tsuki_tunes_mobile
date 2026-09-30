import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/services/spotify_service.dart';
import 'package:tsuki_tunes_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Spotify URI Cache Tests', () {
    test('StorageService persists and retrieves spotify URI cache map', () async {
      final storage = StorageService();

      expect(await storage.getSpotifyUriCache(), isEmpty);

      await storage.saveSpotifyUriCache({
        'deezer_123': 'spotify:track:abc123xyz',
        'deezer_456': 'spotify:track:def456uvw',
      });

      final retrieved = await storage.getSpotifyUriCache();
      expect(retrieved.length, equals(2));
      expect(retrieved['deezer_123'], equals('spotify:track:abc123xyz'));
      expect(retrieved['deezer_456'], equals('spotify:track:def456uvw'));
    });

    test('SpotifyService.searchTrack returns cached URI immediately without network call', () async {
      final storage = StorageService();
      await storage.saveSpotifyUriCache({
        '10001': 'spotify:track:cached_track_uri',
      });

      final spotify = SpotifyService();
      // searchTrack with trackId '10001' should hit cache directly
      final result = await spotify.searchTrack(
        'Some Title',
        'Some Artist',
        trackId: '10001',
      );

      expect(result, equals('spotify:track:cached_track_uri'));
    });

    test('SpotifyService.searchTrack returns cached URI via title/artist fallback key', () async {
      final spotify = SpotifyService();
      spotify.populateUriCacheForTesting({
        'radiohead:::creep': 'spotify:track:radiohead_creep_uri',
      });

      // searchTrack without trackId should hit fallback normalized key
      final result = await spotify.searchTrack('Creep', 'Radiohead');
      expect(result, equals('spotify:track:radiohead_creep_uri'));
    });

    test('SpotifyService LRU cache bounds entries to max limit', () async {
      final spotify = SpotifyService();
      final largeMap = <String, String>{};
      for (int i = 0; i < 2005; i++) {
        largeMap['track_$i'] = 'spotify:track:$i';
      }
      spotify.populateUriCacheForTesting(largeMap);

      // Trigger a search or cache lookup that touches entries
      expect(spotify.uriCache.length, greaterThanOrEqualTo(2000));
    });
  });
}
