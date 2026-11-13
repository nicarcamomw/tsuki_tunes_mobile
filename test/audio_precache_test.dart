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

    test('besides the file count, the folder never weighs more than the limit', () {
      final dir = Directory.systemTemp.createTempSync('tsuki_precache_bytes');
      AudioPrecacheService.cacheDirForTesting = dir;
      AudioPrecacheService.maxCacheBytesForTesting = 50000;
      addTearDown(() {
        AudioPrecacheService.maxCacheBytesForTesting = null;
        AudioPrecacheService.cacheDirForTesting = null;
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final start = DateTime(2026, 1, 1);
      for (var i = 0; i < 6; i++) {
        File('${dir.path}/preview_b$i.mp3')
          ..writeAsBytesSync(List.filled(15000, 1))
          ..setLastModifiedSync(start.add(Duration(minutes: i)));
      }

      precache.forgetInMemoryForTesting();
      expect(precache.getCachedFilePath('b5'), isNotNull);

      final left = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();
      expect(left, {'preview_b3.mp3', 'preview_b4.mp3', 'preview_b5.mp3'},
          reason: '3 x 15000 bytes fit in 50000; the oldest go');
    });

    group('cache folder', () {
      late Directory root;
      setUp(() {
        root = Directory.systemTemp.createTempSync('tsuki_precache_move');
        AudioPrecacheService.cacheDirForTesting = null;
        precache.resetInitForTesting();
        precache.forgetInMemoryForTesting();
      });
      tearDown(() {
        precache.resetInitForTesting();
        precache.forgetInMemoryForTesting();
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      test('previews kept in the old temp folder move to the app cache folder', () async {
        final legacy = Directory('${root.path}/tmp/tsuki_preview_cache')..createSync(recursive: true);
        final base = Directory('${root.path}/cache')..createSync();
        final target = Directory('${base.path}/tsuki_preview_cache')..createSync();
        File('${legacy.path}/preview_a.mp3').writeAsBytesSync(List.filled(15000, 1));
        File('${legacy.path}/preview_b.mp3').writeAsBytesSync(List.filled(15000, 2));
        // Already in the new folder: that copy wins, no duplicate.
        File('${legacy.path}/preview_c.mp3').writeAsBytesSync(List.filled(15000, 3));
        File('${target.path}/preview_c.mp3').writeAsBytesSync(List.filled(15000, 9));

        await precache.init(cacheBase: () async => base, legacyDir: legacy);

        expect(legacy.existsSync(), isFalse, reason: 'emptied and removed');
        expect(target.listSync().map((f) => f.uri.pathSegments.last).toSet(),
            {'preview_a.mp3', 'preview_b.mp3', 'preview_c.mp3'});
        expect(File('${target.path}/preview_c.mp3').readAsBytesSync().first, 9);
        expect(precache.getCachedFilePath('a'), '${target.path}/preview_a.mp3');
      });

      test('when both are the same folder (Android) nothing moves or is forgotten', () async {
        final base = Directory('${root.path}/cache')..createSync();
        final same = Directory('${base.path}/tsuki_preview_cache')..createSync();
        final file = File('${same.path}/preview_x.mp3')..writeAsBytesSync(List.filled(15000, 1));

        await precache.init(cacheBase: () async => base, legacyDir: same);

        expect(file.existsSync(), isTrue);
        expect(precache.getCachedFilePath('x'), file.path);
      });

      test('if the folder can\'t be found, it keeps working in the temp folder', () async {
        await precache.init(cacheBase: () async => throw Exception('no path_provider'));
        // No crash; lookups still answer (nothing cached under this id).
        expect(precache.getCachedFilePath('nothing_here_123'), isNull);
      });
    });

    test('clearCache empties local references cleanly', () {
      precache.clearCache();
      expect(precache.getCachedFilePath('any_id'), isNull);
    });
  });
}
