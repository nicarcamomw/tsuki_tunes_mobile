import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/models/play_day.dart';
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
}
