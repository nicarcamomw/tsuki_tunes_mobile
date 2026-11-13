import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';
import 'package:tsuki_tunes_mobile/domain/entities/weekly_challenge.dart';

// Spanish is the template; every other language must have the same texts
// with the same placeholders, or the app silently shows Spanish (or a text
// missing its number) there.

Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Map<String, String> _messages(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };

// A placeholder is a `{name}` or `{name, plural|select, ...}` whose brace
// doesn't open a branch (branches follow their key: `other{`, `=1{`).
final _placeholder = RegExp(r'(?<![A-Za-z0-9_])\{([A-Za-z_][A-Za-z0-9_]*)\s*[},]');

Set<String> _placeholders(String message) =>
    {for (final m in _placeholder.allMatches(message)) m.group(1)!};

void main() {
  final template = _messages(_arb('es'));
  final others = {
    for (final code in AppLanguage.values.map((l) => l.code))
      if (code != 'es') code: _messages(_arb(code)),
  };

  test('every language has every text, and no extra ones', () {
    for (final MapEntry(key: code, value: messages) in others.entries) {
      final missing = template.keys.where((k) => !messages.containsKey(k));
      final extra = messages.keys.where((k) => !template.containsKey(k));
      expect(missing, isEmpty, reason: 'Missing in app_$code.arb');
      expect(extra, isEmpty, reason: 'Not in the template, in app_$code.arb');
    }
  });

  test('translations use the same placeholders as the template', () {
    for (final MapEntry(key: code, value: messages) in others.entries) {
      for (final MapEntry(key: key, value: text) in template.entries) {
        final translated = messages[key];
        if (translated == null) continue;
        expect(_placeholders(translated), _placeholders(text),
            reason: '"$key" in app_$code.arb');
      }
    }
  });

  test('no text is left empty', () {
    for (final code in ['es', ...others.keys]) {
      final empty = _messages(_arb(code))
          .entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key);
      expect(empty, isEmpty, reason: 'Empty in app_$code.arb');
    }
  });

  group('plurals', () {
    final es = AppStrings.of(AppLanguage.es);
    final en = AppStrings.of(AppLanguage.en);
    final ja = AppStrings.of(AppLanguage.ja);

    test('one and many', () {
      expect(es.trackCountLabel(1), '1 canción');
      expect(es.trackCountLabel(2), '2 canciones');
      expect(es.trackCountLabel(0), '0 canciones');
      expect(en.trackCountLabel(1), '1 track');
      expect(en.trackCountLabel(21), '21 tracks');
      expect(ja.trackCountLabel(21), '21 曲');
    });

    test('zero, one and many', () {
      expect(es.radarReleasedAgo(0), 'HOY');
      expect(es.radarReleasedAgo(1), 'AYER');
      expect(es.radarReleasedAgo(5), 'HACE 5 DÍAS');
      expect(es.radarReleasedAgo(-1), 'PRÓXIMAMENTE');
      expect(en.moonMixProgress(0), 'Listen to music this cycle to fill it');
      expect(en.moonMixProgress(1), '1 song so far this cycle');
      expect(en.moonMixProgress(3), '3 songs so far this cycle');
    });

    test('weekly challenges and Wrapped recaps', () {
      expect(es.weeklyTimeLeft(const Duration(days: 1, hours: 3)), 'Queda 1 día');
      expect(es.weeklyTimeLeft(const Duration(days: 3)), 'Quedan 3 días');
      expect(en.weeklyTimeLeft(const Duration(hours: 5)), '5 h left');
      expect(ja.weeklyTimeLeft(const Duration(days: 2)), '残り2日');
      expect(es.weeklyChallengeText(const WeeklyChallenge(ChallengeKind.album, 1)),
          'Escucha un álbum en orden (5+ canciones seguidas)');
      expect(en.weeklyChallengeText(const WeeklyChallenge(ChallengeKind.album, 2)), 'Play 2 albums in order');
      expect(en.weeklyChallengeText(const WeeklyChallenge(ChallengeKind.oneArtist, 15)), 'Listen to 15 songs by one artist');
      expect(es.wrappedHoursOfMusic(1), 'Eso es 1 hora de música');
      expect(en.wrappedHoursOfMusic(4), "That's 4 hours of music");
      expect(es.wrappedVsPrevious(-12, 'septiembre'), '12% menos que en septiembre');
      expect(ja.wrappedVsPrevious(23, '9月'), '9月より23%多い');
      expect(es.wrappedPeriod(2026, 10), 'OCTUBRE 2026');
      expect(ja.wrappedPeriod(2026, 10), '2026年10月');
      expect(en.wrappedPeriod(2026, null), '2026');
      expect(en.monthName(12), 'December');
      expect(en.wrappedAura('loyal').$1, 'Loyal soul');
      expect(es.wrappedAura('anything').$1, 'Equilibrio');
      expect(en.wrappedDayPart(0), 'Late night');
      expect(en.wrappedNoDataFor(monthly: true), 'Not enough data for this month');
    });

    test('each language keeps its clock', () {
      expect(en.wrappedHourLabel(0), '12:00 AM');
      expect(es.wrappedHourLabel(13), '1:00 PM');
      expect(en.wrappedHourLabel(12), '12:00 PM');
      expect(ja.wrappedHourLabel(23), '23:00');
    });

    test('numbers are not grouped', () {
      expect(en.wrappedYear(2026), 'YOUR 2026 IN MUSIC');
      expect(es.longDate(DateTime(2026, 1, 5)), '5 ene 2026');
      expect(en.clockTotalYear(12345), '◈ 12345 PLAYS THIS YEAR // CLOCK.SYS');
    });
  });
}
