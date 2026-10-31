import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_language.dart';
import 'package:tsuki_tunes_mobile/core/localization/app_strings.dart';

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

    test('numbers are not grouped', () {
      expect(en.wrappedYear(2026), 'YOUR 2026 IN MUSIC');
      expect(es.longDate(DateTime(2026, 1, 5)), '5 ene 2026');
      expect(en.clockTotalYear(12345), '◈ 12345 PLAYS THIS YEAR // CLOCK.SYS');
    });
  });
}
