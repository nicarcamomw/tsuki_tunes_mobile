import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/time_machine_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/play_day.dart';
import 'package:tsuki_tunes_mobile/presentation/state/library_provider.dart';

PlayDay _day(String date, Map<String, int> plays) => PlayDay(
      date: date,
      plays: plays,
      tracks: {
        for (final id in plays.keys)
          id: PlayDayTrack(id: id, title: 'Song $id', artistName: 'Artist $id'),
      },
    );

ListenedTrackData _listened(String id, DateTime at) => ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: 'Artist',
      albumTitle: '',
      albumId: '',
      coverUrl: '',
      duration: 200,
      listenedAt: at,
    );

void main() {
  final anchor = DateTime(2025, 10, 27);

  group('dates', () {
    test('a year before Feb 29 is Feb 28', () {
      expect(TimeMachineService.yearsAgo(DateTime(2028, 2, 29), 1),
          DateTime(2027, 2, 28));
    });

    test('a month before Mar 31 clamps to the end of February', () {
      expect(TimeMachineService.monthsAgo(DateTime(2026, 3, 31), 1),
          DateTime(2026, 2, 28));
      expect(TimeMachineService.monthsAgo(DateTime(2026, 1, 15), 1),
          DateTime(2025, 12, 15));
    });
  });

  group('build', () {
    test('a song on repeat that exact day wins', () {
      final m = TimeMachineService.build(
        anchor: anchor,
        days: [_day('2025-10-27', {'x': 5, 'y': 1})],
        listened: [_listened('z', DateTime(2025, 10, 27, 12))],
      )!;
      expect(m.kind, TimeMachineKind.plays);
      expect(m.exactDay, isTrue);
      expect(m.hero.track.id, 'x');
      expect(m.onRepeat, isTrue);
    });

    test('a repeat that week beats a single play on the exact day', () {
      final m = TimeMachineService.build(
        anchor: anchor,
        days: [
          _day('2025-10-27', {'lonely': 1}),
          _day('2025-10-25', {'hit': 4}),
        ],
        listened: const [],
      )!;
      expect(m.exactDay, isFalse);
      expect(m.hero.track.id, 'hit');
      expect(m.hero.count, 4);
    });

    test('falls back to discoveries when there is no play log', () {
      final m = TimeMachineService.build(
        anchor: anchor,
        days: const [],
        listened: [
          _listened('late', DateTime(2025, 10, 27, 22)),
          _listened('early', DateTime(2025, 10, 27, 9)),
          _listened('other-week', DateTime(2025, 10, 10)),
        ],
      )!;
      expect(m.kind, TimeMachineKind.discoveries);
      expect(m.exactDay, isTrue);
      expect(m.tracks.map((t) => t.track.id), ['early', 'late']);
      expect(m.onRepeat, isFalse);
    });

    test('uses the surrounding week when the exact day is empty', () {
      final m = TimeMachineService.build(
        anchor: anchor,
        days: const [],
        listened: [_listened('near', DateTime(2025, 10, 29, 8))],
      )!;
      expect(m.exactDay, isFalse);
      expect(m.hero.track.id, 'near');
    });

    test('nothing that week means no moment', () {
      expect(
        TimeMachineService.build(
          anchor: anchor,
          days: [_day('2025-11-10', {'x': 9})],
          listened: [_listened('far', DateTime(2025, 9, 1))],
        ),
        isNull,
      );
    });
  });
}
