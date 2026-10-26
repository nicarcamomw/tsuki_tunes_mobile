import 'dart:math';

/// Lunar astronomy from Jean Meeus, "Astronomical Algorithms" (2nd ed.):
/// illumination (ch. 48), principal phase times (ch. 49) and lunar eclipses
/// (ch. 54). Phase times are accurate to about a minute; no network needed.

enum MoonPhaseKind { newMoon, firstQuarter, fullMoon, lastQuarter }

enum MoonPhaseName {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

enum LunarEclipseKind { penumbral, partial, total }

class MoonEvent {
  final MoonPhaseKind kind;
  final DateTime time; // UTC

  const MoonEvent(this.kind, this.time);
}

class LunarEclipse {
  final LunarEclipseKind kind;
  final DateTime greatest; // UTC
  /// Fraction of the Moon's diameter inside Earth's umbra (negative when the
  /// eclipse is only penumbral).
  final double umbralMagnitude;
  final Duration partialSemiDuration;
  final Duration totalSemiDuration;
  final Duration penumbralSemiDuration;

  const LunarEclipse({
    required this.kind,
    required this.greatest,
    required this.umbralMagnitude,
    required this.partialSemiDuration,
    required this.totalSemiDuration,
    required this.penumbralSemiDuration,
  });

  /// The umbral (visibly red/dark) part; penumbral eclipses have none.
  DateTime get umbralStart => greatest.subtract(partialSemiDuration);
  DateTime get umbralEnd => greatest.add(partialSemiDuration);
  DateTime get start => greatest.subtract(penumbralSemiDuration);
  DateTime get end => greatest.add(penumbralSemiDuration);

  bool isUmbralAt(DateTime t) =>
      kind != LunarEclipseKind.penumbral &&
      !t.isBefore(umbralStart) &&
      !t.isAfter(umbralEnd);
}

class MoonSnapshot {
  final DateTime at;
  /// 0 = new, 1 = full.
  final double illumination;
  final bool waxing;
  /// Days since the last new moon.
  final double ageDays;
  final MoonPhaseName name;
  final MoonEvent previousNew;
  final MoonEvent nextNew;
  final MoonEvent previousFull;
  final MoonEvent nextFull;
  /// The next four principal phases after [at], in order.
  final List<MoonEvent> upcoming;

  const MoonSnapshot({
    required this.at,
    required this.illumination,
    required this.waxing,
    required this.ageDays,
    required this.name,
    required this.previousNew,
    required this.nextNew,
    required this.previousFull,
    required this.nextFull,
    required this.upcoming,
  });

  /// Signed phase position in the cycle: 0 new → 0.5 full → 1 new.
  double get cycleFraction => waxing ? illumination / 2 : 1 - illumination / 2;

  /// The full-moon window: the nights around the exact full moon, when the
  /// Moon looks full to the eye (about 98% lit or more).
  bool get isFullMoonWindow => fullMoonDistance <= MoonCalculator.fullMoonWindow;

  Duration get fullMoonDistance {
    final a = at.difference(previousFull.time).abs();
    final b = nextFull.time.difference(at).abs();
    return a < b ? a : b;
  }

  /// The full moon this window belongs to (nearest one).
  DateTime get nearestFull =>
      at.difference(previousFull.time).abs() < nextFull.time.difference(at).abs()
          ? previousFull.time
          : nextFull.time;
}

class MoonCalculator {
  static const double synodicMonth = 29.530588861;
  static const Duration fullMoonWindow = Duration(hours: 36);
  static const Duration _eventWindow = Duration(hours: 18);

  // ── Time conversions ──

  static double julianDay(DateTime t) =>
      t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static DateTime fromJulianDay(double jd) => DateTime.fromMillisecondsSinceEpoch(
      ((jd - 2440587.5) * 86400000).round(),
      isUtc: true);

  /// Approximate ΔT = TT − UT in seconds (Espenak & Meeus polynomials).
  static double deltaTSeconds(double year) {
    if (year >= 2005 && year < 2050) {
      final t = year - 2000;
      return 62.92 + 0.32217 * t + 0.005589 * t * t;
    }
    if (year >= 1986 && year < 2005) {
      final t = year - 2000;
      return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * pow(t, 3) +
          0.000651814 * pow(t, 4) + 0.00002373599 * pow(t, 5);
    }
    if (year >= 2050 && year < 2150) {
      return -20 + 32 * pow((year - 1820) / 100, 2) - 0.5628 * (2150 - year);
    }
    final u = (year - 1820) / 100;
    return -20 + 32 * u * u;
  }

  static DateTime _fromJde(double jde) {
    final approx = fromJulianDay(jde);
    final year = approx.year + (approx.month - 0.5) / 12;
    return fromJulianDay(jde - deltaTSeconds(year) / 86400);
  }

  static double _rad(double deg) => deg * pi / 180;

  static double _norm(double deg) {
    final r = deg % 360;
    return r < 0 ? r + 360 : r;
  }

  // ── Illumination (Meeus ch. 48, low precision: error < 0.0014) ──

  static ({double illumination, bool waxing}) illuminationAt(DateTime t) {
    final tc = (julianDay(t) - 2451545.0) / 36525;
    final d = _norm(297.8501921 + 445267.1114034 * tc - 0.0018819 * tc * tc +
        pow(tc, 3) / 545868 - pow(tc, 4) / 113065000);
    final m = _norm(357.5291092 + 35999.0502909 * tc - 0.0001536 * tc * tc +
        pow(tc, 3) / 24490000);
    final mp = _norm(134.9633964 + 477198.8675055 * tc + 0.0087414 * tc * tc +
        pow(tc, 3) / 69699 - pow(tc, 4) / 14712000);
    final i = 180 -
        d -
        6.289 * sin(_rad(mp)) +
        2.100 * sin(_rad(m)) -
        1.274 * sin(_rad(2 * d - mp)) -
        0.658 * sin(_rad(2 * d)) -
        0.214 * sin(_rad(2 * mp)) -
        0.110 * sin(_rad(d));
    return (illumination: (1 + cos(_rad(i))) / 2, waxing: d < 180);
  }

  // ── Principal phases (Meeus ch. 49) ──

  static double _k(DateTime t) {
    final year = t.year + (t.difference(DateTime.utc(t.year)).inSeconds / (365.25 * 86400));
    return (year - 2000) * 12.3685;
  }

  /// [k] must be an integer for new moons, +0.25 first quarter, +0.5 full,
  /// +0.75 last quarter.
  static DateTime phaseTime(double k) {
    final frac = k - k.floorToDouble();
    final kind = frac < 0.125
        ? MoonPhaseKind.newMoon
        : frac < 0.375
            ? MoonPhaseKind.firstQuarter
            : frac < 0.625
                ? MoonPhaseKind.fullMoon
                : MoonPhaseKind.lastQuarter;

    final t = k / 1236.85;
    final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
    var jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * t2 -
        0.000000150 * t3 + 0.00000000073 * t4;
    final e = 1 - 0.002516 * t - 0.0000074 * t2;
    final m = _rad(_norm(2.5534 + 29.10535670 * k - 0.0000014 * t2 - 0.00000011 * t3));
    final mp = _rad(_norm(201.5643 + 385.81693528 * k + 0.0107582 * t2 +
        0.00001238 * t3 - 0.000000058 * t4));
    final f = _rad(_norm(160.7108 + 390.67050284 * k - 0.0016118 * t2 -
        0.00000227 * t3 + 0.000000011 * t4));
    final om = _rad(_norm(124.7746 - 1.56375588 * k + 0.0020672 * t2 + 0.00000215 * t3));

    double c;
    switch (kind) {
      case MoonPhaseKind.newMoon:
      case MoonPhaseKind.fullMoon:
        final full = kind == MoonPhaseKind.fullMoon;
        c = (full ? -0.40614 : -0.40720) * sin(mp) +
            (full ? 0.17302 : 0.17241) * e * sin(m) +
            (full ? 0.01614 : 0.01608) * sin(2 * mp) +
            (full ? 0.01043 : 0.01039) * sin(2 * f) +
            (full ? 0.00734 : 0.00739) * e * sin(mp - m) -
            (full ? 0.00515 : 0.00514) * e * sin(mp + m) +
            (full ? 0.00209 : 0.00208) * e * e * sin(2 * m) -
            0.00111 * sin(mp - 2 * f) -
            0.00057 * sin(mp + 2 * f) +
            0.00056 * e * sin(2 * mp + m) -
            0.00042 * sin(3 * mp) +
            0.00042 * e * sin(m + 2 * f) +
            0.00038 * e * sin(m - 2 * f) -
            0.00024 * e * sin(2 * mp - m) -
            0.00017 * sin(om) -
            0.00007 * sin(mp + 2 * m) +
            0.00004 * sin(2 * mp - 2 * f) +
            0.00004 * sin(3 * m) +
            0.00003 * sin(mp + m - 2 * f) +
            0.00003 * sin(2 * mp + 2 * f) -
            0.00003 * sin(mp + m + 2 * f) +
            0.00003 * sin(mp - m + 2 * f) -
            0.00002 * sin(mp - m - 2 * f) -
            0.00002 * sin(3 * mp + m) +
            0.00002 * sin(4 * mp);
      case MoonPhaseKind.firstQuarter:
      case MoonPhaseKind.lastQuarter:
        c = -0.62801 * sin(mp) +
            0.17172 * e * sin(m) -
            0.01183 * e * sin(mp + m) +
            0.00862 * sin(2 * mp) +
            0.00804 * sin(2 * f) +
            0.00454 * e * sin(mp - m) +
            0.00204 * e * e * sin(2 * m) -
            0.00180 * sin(mp - 2 * f) -
            0.00070 * sin(mp + 2 * f) -
            0.00040 * sin(3 * mp) -
            0.00034 * e * sin(2 * mp - m) +
            0.00032 * e * sin(m + 2 * f) +
            0.00032 * e * sin(m - 2 * f) -
            0.00028 * e * e * sin(mp + 2 * m) +
            0.00027 * e * sin(2 * mp + m) -
            0.00017 * sin(om) -
            0.00005 * sin(mp - m - 2 * f) +
            0.00004 * sin(2 * mp + 2 * f) -
            0.00004 * sin(mp + m + 2 * f) +
            0.00004 * sin(mp - 2 * m) +
            0.00003 * sin(mp + m - 2 * f) +
            0.00003 * sin(3 * m) +
            0.00002 * sin(2 * mp - 2 * f) +
            0.00002 * sin(mp - m + 2 * f) -
            0.00002 * sin(3 * mp + m);
        final w = 0.00306 -
            0.00038 * e * cos(m) +
            0.00026 * cos(mp) -
            0.00002 * cos(mp - m) +
            0.00002 * cos(mp + m) +
            0.00002 * cos(2 * f);
        c += kind == MoonPhaseKind.firstQuarter ? w : -w;
    }

    final a = [
      299.77 + 0.107408 * k - 0.009173 * t2,
      251.88 + 0.016321 * k,
      251.83 + 26.651886 * k,
      349.42 + 36.412478 * k,
      84.66 + 18.206239 * k,
      141.74 + 53.303771 * k,
      207.14 + 2.453732 * k,
      154.84 + 7.306860 * k,
      34.52 + 27.261239 * k,
      207.19 + 0.121824 * k,
      291.34 + 1.844379 * k,
      161.72 + 24.198154 * k,
      239.56 + 25.513099 * k,
      331.55 + 3.592518 * k,
    ];
    const coef = [
      0.000325, 0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060,
      0.000056, 0.000047, 0.000042, 0.000040, 0.000037, 0.000035, 0.000023,
    ];
    var planetary = 0.0;
    for (var i = 0; i < a.length; i++) {
      planetary += coef[i] * sin(_rad(_norm(a[i])));
    }

    jde += c + planetary;
    return _fromJde(jde);
  }

  static double _offset(MoonPhaseKind kind) => switch (kind) {
        MoonPhaseKind.newMoon => 0,
        MoonPhaseKind.firstQuarter => 0.25,
        MoonPhaseKind.fullMoon => 0.5,
        MoonPhaseKind.lastQuarter => 0.75,
      };

  /// All principal phases between [from] and [to], in order.
  static List<MoonEvent> eventsBetween(DateTime from, DateTime to) {
    final events = <MoonEvent>[];
    final start = _k(from).floorToDouble() - 1;
    final end = _k(to).ceilToDouble() + 1;
    for (var k = start; k <= end; k++) {
      for (final kind in MoonPhaseKind.values) {
        final time = phaseTime(k + _offset(kind));
        if (!time.isBefore(from) && !time.isAfter(to)) {
          events.add(MoonEvent(kind, time));
        }
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  static MoonSnapshot snapshot(DateTime now) {
    final at = now.toUtc();
    const span = Duration(days: 40);
    final around = eventsBetween(at.subtract(span), at.add(span));
    MoonEvent last(MoonPhaseKind k) =>
        around.lastWhere((e) => e.kind == k && !e.time.isAfter(at));
    MoonEvent next(MoonPhaseKind k) =>
        around.firstWhere((e) => e.kind == k && e.time.isAfter(at));

    final ill = illuminationAt(at);
    final prevNew = last(MoonPhaseKind.newMoon);
    final upcoming = around.where((e) => e.time.isAfter(at)).take(4).toList();

    // Named phases follow the exact events within ±18 h, like almanacs do;
    // in between, the intermediate names.
    MoonPhaseName name;
    final nearest = around.reduce((a, b) =>
        a.time.difference(at).abs() <= b.time.difference(at).abs() ? a : b);
    if (nearest.time.difference(at).abs() <= _eventWindow) {
      name = switch (nearest.kind) {
        MoonPhaseKind.newMoon => MoonPhaseName.newMoon,
        MoonPhaseKind.firstQuarter => MoonPhaseName.firstQuarter,
        MoonPhaseKind.fullMoon => MoonPhaseName.fullMoon,
        MoonPhaseKind.lastQuarter => MoonPhaseName.lastQuarter,
      };
    } else {
      final lastEvent = around.lastWhere((e) => !e.time.isAfter(at));
      name = switch (lastEvent.kind) {
        MoonPhaseKind.newMoon => MoonPhaseName.waxingCrescent,
        MoonPhaseKind.firstQuarter => MoonPhaseName.waxingGibbous,
        MoonPhaseKind.fullMoon => MoonPhaseName.waningGibbous,
        MoonPhaseKind.lastQuarter => MoonPhaseName.waningCrescent,
      };
    }

    return MoonSnapshot(
      at: at,
      illumination: ill.illumination,
      waxing: ill.waxing,
      ageDays: at.difference(prevNew.time).inMinutes / 1440,
      name: name,
      previousNew: prevNew,
      nextNew: next(MoonPhaseKind.newMoon),
      previousFull: last(MoonPhaseKind.fullMoon),
      nextFull: next(MoonPhaseKind.fullMoon),
      upcoming: upcoming,
    );
  }

  // ── Lunar eclipses (Meeus ch. 54) ──

  /// The eclipse at the full moon with index [k] (must end in .5), if any.
  static LunarEclipse? eclipseAt(double k) {
    final t = k / 1236.85;
    final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
    final fDeg = _norm(160.7108 + 390.67050284 * k - 0.0016118 * t2 -
        0.00000227 * t3 + 0.000000011 * t4);
    if (sin(_rad(fDeg)).abs() > 0.36) return null;

    final jdeMean = 2451550.09766 + 29.530588861 * k + 0.00015437 * t2 -
        0.000000150 * t3 + 0.00000000073 * t4;
    final m = _rad(_norm(2.5534 + 29.10535670 * k - 0.0000014 * t2 - 0.00000011 * t3));
    final mp = _rad(_norm(201.5643 + 385.81693528 * k + 0.0107582 * t2 +
        0.00001238 * t3 - 0.000000058 * t4));
    final om = _rad(_norm(124.7746 - 1.56375588 * k + 0.0020672 * t2 + 0.00000215 * t3));
    final e = 1 - 0.002516 * t - 0.0000074 * t2;
    final f1 = _rad(fDeg - 0.02665 * sin(om));
    final a1 = _rad(_norm(299.77 + 0.107408 * k - 0.009173 * t2));

    final jdeMax = jdeMean -
        0.4065 * sin(mp) +
        0.1727 * e * sin(m) +
        0.0161 * sin(2 * mp) -
        0.0097 * sin(2 * f1) +
        0.0073 * e * sin(mp - m) -
        0.0050 * e * sin(mp + m) -
        0.0023 * sin(mp - 2 * f1) +
        0.0021 * e * sin(2 * m) +
        0.0012 * sin(mp + 2 * f1) +
        0.0006 * e * sin(2 * mp + m) -
        0.0004 * sin(3 * mp) -
        0.0003 * e * sin(m + 2 * f1) +
        0.0003 * sin(a1) -
        0.0002 * e * sin(m - 2 * f1) -
        0.0002 * e * sin(2 * mp - m) -
        0.0002 * sin(om);

    final p = 0.2070 * e * sin(m) +
        0.0024 * e * sin(2 * m) -
        0.0392 * sin(mp) +
        0.0116 * sin(2 * mp) -
        0.0073 * e * sin(mp + m) +
        0.0067 * e * sin(mp - m) +
        0.0118 * sin(2 * f1);
    final q = 5.2207 -
        0.0048 * e * cos(m) +
        0.0020 * e * cos(2 * m) -
        0.3299 * cos(mp) -
        0.0060 * e * cos(mp + m) +
        0.0041 * e * cos(mp - m);
    final w = cos(f1).abs();
    final gamma = (p * cos(f1) + q * sin(f1)) * (1 - 0.0048 * w);
    final u = 0.0059 +
        0.0046 * e * cos(m) -
        0.0182 * cos(mp) +
        0.0004 * cos(2 * mp) -
        0.0005 * cos(m + mp);

    final g = gamma.abs();
    final penumbralMag = (1.5573 + u - g) / 0.5450;
    final umbralMag = (1.0128 - u - g) / 0.5450;
    if (penumbralMag <= 0) return null;

    final n = 0.5458 + 0.0400 * cos(mp);
    Duration semi(double r) {
      final v = r * r - gamma * gamma;
      if (v <= 0) return Duration.zero;
      return Duration(seconds: (60 / n * sqrt(v) * 60).round());
    }

    final kind = umbralMag <= 0
        ? LunarEclipseKind.penumbral
        : umbralMag < 1
            ? LunarEclipseKind.partial
            : LunarEclipseKind.total;

    return LunarEclipse(
      kind: kind,
      greatest: _fromJde(jdeMax),
      umbralMagnitude: umbralMag,
      penumbralSemiDuration: semi(1.5573 + u),
      partialSemiDuration: semi(1.0128 - u),
      totalSemiDuration: semi(0.4678 - u),
    );
  }

  /// Eclipses with greatest eclipse between [from] and [to].
  static List<LunarEclipse> eclipsesBetween(DateTime from, DateTime to,
      {bool includePenumbral = false}) {
    final out = <LunarEclipse>[];
    final start = _k(from).floorToDouble() - 1;
    final end = _k(to).ceilToDouble() + 1;
    for (var k = start; k <= end; k++) {
      final ecl = eclipseAt(k + 0.5);
      if (ecl == null) continue;
      if (!includePenumbral && ecl.kind == LunarEclipseKind.penumbral) continue;
      if (ecl.greatest.isBefore(from) || ecl.greatest.isAfter(to)) continue;
      out.add(ecl);
    }
    return out;
  }

  /// The umbral eclipse happening right now, if any.
  static LunarEclipse? eclipseInProgress(DateTime now) {
    final at = now.toUtc();
    for (final e in eclipsesBetween(
        at.subtract(const Duration(days: 1)), at.add(const Duration(days: 1)))) {
      if (e.isUmbralAt(at)) return e;
    }
    return null;
  }

  static LunarEclipse? nextEclipse(DateTime now) {
    final at = now.toUtc();
    final list = eclipsesBetween(
        at.subtract(const Duration(days: 1)), at.add(const Duration(days: 365 * 3)));
    for (final e in list) {
      if (e.umbralEnd.isAfter(at)) return e;
    }
    return null;
  }
}
