import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/track.dart';
import 'package:tsuki_tunes_mobile/services/audio_precache_service.dart';

void main() {
  group('AudioPrecacheService Tests', () {
    final precache = AudioPrecacheService();

    test('getCachedFilePath returns null for non-existent track', () {
      expect(precache.getCachedFilePath('non_existent_id_999'), isNull);
    });

    test('precacheTrack handles empty previewUrl without error', () async {
      final track = Track(
        id: 'no_preview_track',
        title: 'Silent Song',
        artistId: 'art_123',
        artistName: 'Ghost',
        albumId: 'alb_123',
        albumTitle: 'Ghost Album',
        coverUrl: 'https://example.com/cover.jpg',
        previewUrl: '',
        durationSeconds: 30,
      );

      // Should complete immediately without throwing
      await precache.precacheTrack(track);
      expect(precache.getCachedFilePath(track.id), isNull);
    });

    test('clearCache empties local references cleanly', () {
      precache.clearCache();
      expect(precache.getCachedFilePath('any_id'), isNull);
    });
  });
}
