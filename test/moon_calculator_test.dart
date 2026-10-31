import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/logic/moon_calculator.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/moon_glyph.dart';

Matcher within(DateTime expected, Duration tolerance) => predicate<DateTime>(
      (t) => t.difference(expected).abs() <= tolerance,
      'within $tolerance of $expected',
    );

void main() {
  group('principal phases (Meeus ch. 49)', () {
    test('matches the worked example: new moon of 1977 Feb 18', () {
      // JDE 2443192.65118 = 03:37:42 TD; ΔT ≈ 48 s in 1977.
      expect(MoonCalculator.phaseTime(-283),
          within(DateTime.utc(1977, 2, 18, 3, 36, 54), const Duration(seconds: 60)));
    });

    test('matches published 2026 full and new moons', () {
      final events = MoonCalculator.eventsBetween(
          DateTime.utc(2026, 10, 1), DateTime.utc(2026, 12, 31));
      DateTime first(MoonPhaseKind k, int month) =>
          events.firstWhere((e) => e.kind == k && e.time.month == month).time;

      const tol = Duration(minutes: 3);
      expect(first(MoonPhaseKind.fullMoon, 10), within(DateTime.utc(2026, 10, 26, 4, 12), tol));
      expect(first(MoonPhaseKind.fullMoon, 11), within(DateTime.utc(2026, 11, 24, 14, 53), tol));
      expect(first(MoonPhaseKind.fullMoon, 12), within(DateTime.utc(2026, 12, 24, 1, 28), tol));
      expect(first(MoonPhaseKind.newMoon, 11), within(DateTime.utc(2026, 11, 9, 7, 2), tol));
    });

    test('events come in order and cycle new → first → full → last', () {
      final events = MoonCalculator.eventsBetween(
          DateTime.utc(2027, 1, 1), DateTime.utc(2027, 12, 31));
      expect(events.length, inInclusiveRange(48, 50));
      for (var i = 1; i < events.length; i++) {
        expect(events[i].time.isAfter(events[i - 1].time), isTrue);
        expect(events[i].kind.index, (events[i - 1].kind.index + 1) % 4);
      }
    });
  });

  group('snapshot', () {
    test('full moon night of 2026-10-26', () {
      final s = MoonCalculator.snapshot(DateTime.utc(2026, 10, 26, 3));
      expect(s.name, MoonPhaseName.fullMoon);
      expect(s.illumination, greaterThan(0.99));
      expect(s.isFullMoonWindow, isTrue);
      expect(s.upcoming.first.kind, MoonPhaseKind.fullMoon);
    });

    test('new moon, crescent and first quarter', () {
      expect(MoonCalculator.snapshot(DateTime.utc(2026, 11, 9, 7)).name, MoonPhaseName.newMoon);

      final crescent = MoonCalculator.snapshot(DateTime.utc(2026, 11, 12));
      expect(crescent.name, MoonPhaseName.waxingCrescent);
      expect(crescent.waxing, isTrue);
      expect(crescent.illumination, inInclusiveRange(0.03, 0.25));
      expect(crescent.isFullMoonWindow, isFalse);

      final quarter = MoonCalculator.snapshot(DateTime.utc(2026, 11, 17, 11, 47));
      expect(quarter.name, MoonPhaseName.firstQuarter);
      expect(quarter.illumination, closeTo(0.5, 0.03));
    });

    test('the cycle has the eight phases in order and contains today', () {
      for (final at in [
        DateTime.utc(2026, 10, 26, 3), // full
        DateTime.utc(2026, 11, 9, 6), // hours before a new moon
        DateTime.utc(2026, 11, 13), // crescent
      ]) {
        final s = MoonCalculator.snapshot(at);
        final cycle = MoonCalculator.cycleOf(s);
        expect(cycle.map((p) => p.name), MoonPhaseName.values);
        for (var i = 1; i < cycle.length; i++) {
          expect(cycle[i].time.isAfter(cycle[i - 1].time), isTrue);
        }
        final today = cycle.firstWhere((p) => p.name == s.name);
        expect(today.time.difference(at).abs(), lessThan(const Duration(days: 4)));
      }
    });

    test('waning after the full moon', () {
      final s = MoonCalculator.snapshot(DateTime.utc(2026, 10, 29));
      expect(s.name, MoonPhaseName.waningGibbous);
      expect(s.waxing, isFalse);
    });

    test('illumination follows the cycle smoothly', () {
      var prev = MoonCalculator.illuminationAt(DateTime.utc(2026, 11, 9, 8)).illumination;
      for (var h = 12; h < 24 * 15; h += 12) {
        final k = MoonCalculator.illuminationAt(
            DateTime.utc(2026, 11, 9, 8).add(Duration(hours: h))).illumination;
        expect(k, greaterThanOrEqualTo(prev - 0.001));
        prev = k;
      }
    });
  });

  group('lunar eclipses (Meeus ch. 54)', () {
    // Greatest eclipse times from NASA's Five Millennium Canon.
    final nasa = <(DateTime, LunarEclipseKind)>[
      (DateTime.utc(2025, 3, 14, 6, 58), LunarEclipseKind.total),
      (DateTime.utc(2025, 9, 7, 18, 12), LunarEclipseKind.total),
      (DateTime.utc(2026, 3, 3, 11, 34), LunarEclipseKind.total),
      (DateTime.utc(2026, 8, 28, 4, 13), LunarEclipseKind.partial),
      (DateTime.utc(2028, 1, 12, 4, 13), LunarEclipseKind.partial),
      (DateTime.utc(2028, 7, 6, 18, 19), LunarEclipseKind.partial),
      (DateTime.utc(2028, 12, 31, 16, 52), LunarEclipseKind.total),
      (DateTime.utc(2029, 6, 26, 3, 22), LunarEclipseKind.total),
      (DateTime.utc(2029, 12, 20, 22, 42), LunarEclipseKind.total),
    ];

    test('finds every umbral eclipse 2025–2029 with the right type and time', () {
      final found = MoonCalculator.eclipsesBetween(DateTime.utc(2025), DateTime.utc(2030));
      expect(found.length, nasa.length);
      for (var i = 0; i < nasa.length; i++) {
        expect(found[i].kind, nasa[i].$2, reason: '${nasa[i].$1}');
        expect(found[i].greatest, within(nasa[i].$1, const Duration(minutes: 5)));
      }
    });

    test('totality of 2029-06-26 is one of the longest (≈102 min)', () {
      final e = MoonCalculator.eclipsesBetween(DateTime.utc(2029, 6, 1), DateTime.utc(2029, 7, 1)).single;
      expect(e.totalSemiDuration.inMinutes * 2, inInclusiveRange(95, 106));
    });

    test('in-progress detection covers the umbral phase only', () {
      final during = MoonCalculator.eclipseInProgress(DateTime.utc(2028, 12, 31, 16, 50));
      expect(during?.kind, LunarEclipseKind.total);
      expect(MoonCalculator.eclipseInProgress(DateTime.utc(2028, 12, 31, 20)), isNull);
      // An ordinary full moon is not an eclipse.
      expect(MoonCalculator.eclipseInProgress(DateTime.utc(2026, 10, 26, 4, 12)), isNull);
    });

    test('next eclipse after today is the partial of 2028-01-12', () {
      final next = MoonCalculator.nextEclipse(DateTime.utc(2026, 10, 26));
      expect(next?.greatest, within(DateTime.utc(2028, 1, 12, 4, 13), const Duration(minutes: 5)));
    });
  });

  group('moon drawing', () {
    const c = Offset(100, 100);
    const r = 50.0;

    // Along the equator the terminator sits at x = c + (1 − 2k)·r.
    test('crescent is a sliver on the lit side, gibbous covers most of the disk', () {
      final crescent = MoonPainter.litPath(c, r, 0.25, rightSide: true);
      expect(crescent.contains(c + const Offset(0.4 * r, 0)), isFalse);
      expect(crescent.contains(c + const Offset(0.6 * r, 0)), isTrue);
      expect(crescent.contains(c + const Offset(-0.6 * r, 0)), isFalse);

      final gibbous = MoonPainter.litPath(c, r, 0.75, rightSide: true);
      expect(gibbous.contains(c + const Offset(-0.4 * r, 0)), isTrue);
      expect(gibbous.contains(c + const Offset(-0.6 * r, 0)), isFalse);
    });

    test('waning mirrors to the left limb', () {
      final p = MoonPainter.litPath(c, r, 0.25, rightSide: false);
      expect(p.contains(c + const Offset(-0.6 * r, 0)), isTrue);
      expect(p.contains(c + const Offset(0.6 * r, 0)), isFalse);
    });

    test('new and full moon', () {
      expect(MoonPainter.litPath(c, r, 0, rightSide: true).getBounds().isEmpty, isTrue);
      final full = MoonPainter.litPath(c, r, 1, rightSide: true).getBounds();
      expect(full.width, closeTo(2 * r, 0.5));
    });
  });
}
