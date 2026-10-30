import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/play_day.dart';
import 'package:tsuki_tunes_mobile/models/wrapped_data.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/services/wrapped_service.dart';

PlayDayTrack _meta(String id, String artist, {int d = 200}) => PlayDayTrack(
      id: id,
      title: 'Song $id',
      artistName: artist,
      coverUrl: 'https://img/$id.jpg',
      durationSeconds: d,
    );

PlayDay _day(String date, Map<String, int> plays, Map<String, PlayDayTrack> meta,
        {Map<int, int>? hours}) =>
    PlayDay(
      date: date,
      plays: plays,
      tracks: meta,
      hours: hours ?? {20: plays.values.fold(0, (s, v) => s + v)},
      seconds: plays.entries
          .fold(0, (s, e) => s + e.value * (meta[e.key]?.durationSeconds ?? 0)),
    );

ListenedTrackData _listened(String id, String artist, DateTime at) =>
    ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: artist,
      albumTitle: 'Album',
      albumId: 'al',
      coverUrl: '',
      duration: 180,
      listenedAt: at,
    );

void main() {
  final meta = {
    'a': _meta('a', 'SOAD'),
    'b': _meta('b', 'SOAD'),
    'c': _meta('c', 'Deftones'),
  };

  test('uses real play counts when the log has enough plays', () {
    final days = [
      _day('2026-03-01', {'a': 12, 'c': 3}, meta),
      _day('2026-03-02', {'a': 4, 'b': 6, 'c': 8}, meta),
    ];
    final w = WrappedService().generate(days: days, listened: const [], year: 2026);

    expect(w.basedOnPlays, isTrue);
    expect(w.playsSince, DateTime(2026, 3, 1));
    expect(w.totalTracksPlayed, 33);
    expect(w.topTracks.first.trackId, 'a');
    expect(w.topTracks.first.playCount, 16);
    expect(w.topArtists.first.name, 'SOAD');
    expect(w.topArtists.first.playCount, 22);
    expect(w.totalMinutesListened, 33 * 200 ~/ 60);
    expect(w.funFacts.map((f) => f.key), contains('one_hit_wonder'));
    final marathon = w.funFacts.firstWhere((f) => f.key == 'marathon_day');
    expect(marathon.data['date'], '2026-03-02'); // 18 plays vs 15
    expect(marathon.data['count'], 18);
  });

  test('ignores play days from other years', () {
    final days = [_day('2025-12-31', {'a': 50}, meta)];
    final w = WrappedService().generate(days: days, listened: const [], year: 2026);
    expect(w.isEmpty, isTrue);
  });

  test('falls back to discoveries without inventing play counts', () {
    final listened = [
      _listened('1', 'SOAD', DateTime(2026, 2, 1, 10)),
      _listened('2', 'SOAD', DateTime(2026, 2, 3, 10)),
      _listened('3', 'Korn', DateTime(2026, 2, 4, 10)),
    ];
    final days = [_day('2026-10-27', {'a': 2}, meta)]; // too few plays
    final w = WrappedService().generate(days: days, listened: listened, year: 2026);

    expect(w.basedOnPlays, isFalse);
    expect(w.totalTracksPlayed, 3);
    expect(w.topArtists.first.name, 'SOAD');
    expect(w.topArtists.first.playCount, 2, reason: 'songs discovered');
    // Highlights: first discovery per top artist, in artist order.
    expect(w.topTracks.map((t) => t.trackId), ['1', '3']);
    expect(w.funFacts.map((f) => f.key), isNot(contains('one_hit_wonder')));
  });

  group('monthly', () {
    final days = [
      _day('2026-09-10', {'a': 10, 'c': 10}, meta),
      _day('2026-10-02', {'a': 8, 'b': 4}, meta),
      _day('2026-10-05', {'c': 6}, meta),
    ];

    test('only counts that month, and needs fewer plays', () {
      final w = WrappedService().generate(
          days: days, listened: const [], year: 2026, month: 10, now: DateTime(2026, 10, 20));
      expect(w.basedOnPlays, isTrue);
      expect(w.isMonthly, isTrue);
      expect(w.totalTracksPlayed, 18);
      expect(w.topTracks.first.trackId, 'a');
      expect(w.activeDays, 2);
      // October so far: 1st to 20th.
      expect(w.periodDays, 20);
    });

    test('a finished month counts all its days', () {
      final w = WrappedService().generate(
          days: days, listened: const [], year: 2026, month: 9, now: DateTime(2026, 10, 20));
      expect(w.periodDays, 30);
      expect(w.activeDays, 1);
    });

    test('minutes of the month before, to compare', () {
      expect(WrappedService().minutesIn(days, 2026, month: 9), 20 * 200 ~/ 60);
    });

    test('discoveries of only that month', () {
      final listened = [
        _listened('x', 'A', DateTime(2026, 10, 3)),
        _listened('y', 'B', DateTime(2026, 9, 3)),
      ];
      final w = WrappedService().generate(
          days: const [], listened: listened, year: 2026, month: 10);
      expect(w.basedOnPlays, isFalse);
      expect(w.totalTracksPlayed, 1);
      expect(w.activeDays, 1);
    });
  });

  group('aura', () {
    WrappedData data({Map<int, int> hours = const {14: 10}, int plays = 100,
            int artists = 10, int topArtistPlays = 10, int activeDays = 10}) =>
        WrappedData(
          year: 2026,
          topTracks: const [],
          topArtists: [
            WrappedArtistEntry(name: 'X', playCount: topArtistPlays, totalSeconds: 0),
          ],
          totalMinutesListened: 0,
          totalTracksPlayed: plays,
          uniqueTracksCount: plays,
          uniqueArtistsCount: artists,
          favoriteHour: 0,
          hourDistribution: hours,
          funFacts: const [],
          generatedAt: DateTime(2026),
          activeDays: activeDays,
        );

    test('each profile', () {
      expect(WrappedService.auraOf(data(hours: {23: 8, 14: 2})), 'night');
      expect(WrappedService.auraOf(data(hours: {7: 5, 14: 5})), 'dawn');
      expect(WrappedService.auraOf(data(topArtistPlays: 50)), 'loyal');
      expect(WrappedService.auraOf(data(plays: 300, activeDays: 5)), 'marathon');
      expect(WrappedService.auraOf(data(artists: 60)), 'explorer');
      expect(WrappedService.auraOf(data()), 'balance');
    });

    test('day parts add up', () {
      final parts = WrappedService.dayParts({2: 1, 8: 1, 15: 1, 21: 1});
      expect(parts, [0.25, 0.25, 0.25, 0.25]);
    });
  });
}
