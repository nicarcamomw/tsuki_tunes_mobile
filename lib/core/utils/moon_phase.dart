import 'dart:math';

enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

class MoonPhaseCalculator {
  static const _synodicMonth = 29.53058770576;
  static const _knownNewMoon = 2451550.1; // Jan 6, 2000 18:14 UTC (JD)

  static double _toJulianDay(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year;
    final m = utc.month;
    final d = utc.day +
        utc.hour / 24.0 +
        utc.minute / 1440.0 +
        utc.second / 86400.0;
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        (153 * mm + 2) ~/ 5 +
        365 * yy +
        yy ~/ 4 -
        yy ~/ 100 +
        yy ~/ 400 -
        32045;
  }

  static double age(DateTime date) {
    final jd = _toJulianDay(date);
    final diff = jd - _knownNewMoon;
    return diff % _synodicMonth;
  }

  static double illumination(DateTime date) {
    final a = age(date);
    return (1 - cos(2 * pi * a / _synodicMonth)) / 2;
  }

  static MoonPhase phase(DateTime date) {
    final a = age(date);
    final fraction = a / _synodicMonth;
    if (fraction < 0.0338) return MoonPhase.newMoon;
    if (fraction < 0.216) return MoonPhase.waxingCrescent;
    if (fraction < 0.284) return MoonPhase.firstQuarter;
    if (fraction < 0.466) return MoonPhase.waxingGibbous;
    if (fraction < 0.534) return MoonPhase.fullMoon;
    if (fraction < 0.716) return MoonPhase.waningGibbous;
    if (fraction < 0.784) return MoonPhase.lastQuarter;
    if (fraction < 0.966) return MoonPhase.waningCrescent;
    return MoonPhase.newMoon;
  }

  static String emoji(MoonPhase p) {
    switch (p) {
      case MoonPhase.newMoon:
        return '🌑';
      case MoonPhase.waxingCrescent:
        return '🌒';
      case MoonPhase.firstQuarter:
        return '🌓';
      case MoonPhase.waxingGibbous:
        return '🌔';
      case MoonPhase.fullMoon:
        return '🌕';
      case MoonPhase.waningGibbous:
        return '🌖';
      case MoonPhase.lastQuarter:
        return '🌗';
      case MoonPhase.waningCrescent:
        return '🌘';
    }
  }

  static String japaneseName(MoonPhase p) {
    switch (p) {
      case MoonPhase.newMoon:
        return '新月';
      case MoonPhase.waxingCrescent:
        return '三日月';
      case MoonPhase.firstQuarter:
        return '上弦';
      case MoonPhase.waxingGibbous:
        return '十日夜';
      case MoonPhase.fullMoon:
        return '満月';
      case MoonPhase.waningGibbous:
        return '十六夜';
      case MoonPhase.lastQuarter:
        return '下弦';
      case MoonPhase.waningCrescent:
        return '二十六夜';
    }
  }

  static String englishName(MoonPhase p) {
    switch (p) {
      case MoonPhase.newMoon:
        return 'New Moon';
      case MoonPhase.waxingCrescent:
        return 'Waxing Crescent';
      case MoonPhase.firstQuarter:
        return 'First Quarter';
      case MoonPhase.waxingGibbous:
        return 'Waxing Gibbous';
      case MoonPhase.fullMoon:
        return 'Full Moon';
      case MoonPhase.waningGibbous:
        return 'Waning Gibbous';
      case MoonPhase.lastQuarter:
        return 'Last Quarter';
      case MoonPhase.waningCrescent:
        return 'Waning Crescent';
    }
  }
}
