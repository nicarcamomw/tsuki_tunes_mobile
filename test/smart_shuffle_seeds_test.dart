import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/smart_shuffle_seeds.dart';

Track _t(String id, String artist) => Track(
    id: id, title: id, artistId: artist, artistName: artist, albumId: '', albumTitle: '',
    coverUrl: '', previewUrl: '', durationSeconds: 180);

void main() {
  group('listSeeds', () {
    test('one song of each main artist, the most present first', () {
      final list = [
        _t('a1', 'A'),
        for (var i = 0; i < 5; i++) _t('b$i', 'B'),
        for (var i = 0; i < 3; i++) _t('c$i', 'C'),
        _t('d1', 'D'),
      ];
      final seeds = listSeeds(list, max: 3, random: Random(1));
      expect(seeds.map((t) => t.artistId), ['B', 'C', 'A']);
    });

    test('an empty list gives none', () => expect(listSeeds(const []), isEmpty));
  });

  group('RecentRecommendations', () {
    final now = DateTime(2026, 11, 14, 12);

    test('a played one stays out for 14 days, then comes back', () {
      final r = RecentRecommendations()..record('x', now);
      expect(r.isRecent('x', now.add(const Duration(days: 13))), isTrue);
      expect(r.isRecent('x', now.add(const Duration(days: 14))), isFalse);
      expect(r.isRecent('y', now), isFalse);
    });

    test('kept across restarts, old ones dropped, and bounded', () {
      final r = RecentRecommendations()
        ..record('old', now.subtract(const Duration(days: 30)))
        ..record('new', now);
      final back = RecentRecommendations.fromJson(r.toJson())..prune(now);
      expect(back.seen.keys, ['new']);

      final many = RecentRecommendations();
      for (var i = 0; i < RecentRecommendations.capacity + 50; i++) {
        many.record('t$i', now);
      }
      expect(many.seen.length, RecentRecommendations.capacity);
      expect(many.isRecent('t0', now), isFalse, reason: 'the oldest go first');
    });
  });
}
