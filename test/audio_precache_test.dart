import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_precache_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';

void main() {
  group('AudioPrecacheService Tests', () {
    final precache = AudioPrecacheService();

    test('getCachedFilePath returns null for non-existent track', () {
      expect(precache.getCachedFilePath('non_existent_id_999'), isNull);
    });

    test('precacheTrack handles empty previewUrl without error', () async {
      final track = const Track(
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

    // B8: previews from earlier sessions are found on disk at start,
    // oldest first, and pruned to the limit, instead of piling up.
    test('previews left by earlier sessions are pruned at start, oldest first', () {
      // Its own folder: other test files use the shared one in parallel.
      final dir = Directory.systemTemp.createTempSync('tsuki_precache_test');
      AudioPrecacheService.cacheDirForTesting = dir;
      addTearDown(() {
        AudioPrecacheService.cacheDirForTesting = null;
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final start = DateTime(2026, 1, 1);
      for (var i = 0; i < 30; i++) {
        File('${dir.path}/preview_old$i.mp3')
          ..writeAsBytesSync(List.filled(15000, 1))
          ..setLastModifiedSync(start.add(Duration(minutes: i)));
      }

      precache.forgetInMemoryForTesting(); // the app opening again
      expect(precache.getCachedFilePath('old29'), isNotNull);

      final left = dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
      expect(left, hasLength(25));
      for (var i = 0; i < 5; i++) {
        expect(left.contains('preview_old$i.mp3'), isFalse, reason: 'the oldest go');
      }
      expect(left.contains('preview_old5.mp3'), isTrue);
    });

    test('clearCache empties local references cleanly', () {
      precache.clearCache();
      expect(precache.getCachedFilePath('any_id'), isNull);
    });
  });
}
