import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/theme/design_tokens.dart';

// The polish plan's design tokens stay the only values: a loose literal in
// lib/presentation fails here, with the file and line to fix (or run
// tool/design_tokens/migrate.py).

List<String> _offenders(RegExp pattern, {bool Function(String line)? allow}) {
  final hits = <String>[];
  for (final dir in ['lib/presentation', 'lib/core/theme']) {
    for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//') || l.trimLeft().startsWith('///')) continue;
        if (pattern.hasMatch(l) && !(allow?.call(l) ?? false)) hits.add('${f.path}:${i + 1}: ${l.trim()}');
      }
    }
  }
  return hits;
}

void main() {
  test('D-01: every font size is a token', () {
    expect(_offenders(RegExp(r'fontSize: *\d')), isEmpty);
  });

  test('D-02: no informative text under the minimum', () {
    expect(AppFontSize.micro, greaterThanOrEqualTo(10));
    expect(_offenders(RegExp(r'fontSize: *[0-9]')), isEmpty);
  });

  test('D-03: every corner radius is a token', () {
    expect(_offenders(RegExp(r'Radius\.circular\( *\d')), isEmpty);
    expect(_offenders(RegExp(r'(borderRadius: *|this\.borderRadius = )\d')), isEmpty);
  });

  test('D-08: snack bars go through AppSnack', () {
    expect(
      _offenders(RegExp(r'\bSnackBar\(|SnackBarAction\('), allow: (_) => false)
          // Paths come with backslashes on Windows.
          .where((hit) => !hit.replaceAll(r'\', '/').contains('widgets/app_snack.dart'))
          .toList(),
      isEmpty,
    );
  });

  test('E-04: screens open with the app transition, not MaterialPageRoute', () {
    expect(_offenders(RegExp(r'MaterialPageRoute')), isEmpty);
  });

  test('D-04: transitions take a motion token', () {
    // duration: Duration(milliseconds: N) for N up to 650 is a transition;
    // longer ones are ambient loops (breathing, sakura) and stay.
    final short = RegExp(r'\b(duration|reverseDuration|transitionDuration|reverseTransitionDuration): *(const +)?'
        r'Duration\(milliseconds: *([1-9]\d?|[1-5]\d\d|6[0-4]\d|650)\)');
    expect(_offenders(short), isEmpty);
  });

  test('D-05: screens use one side margin', () {
    final loose = RegExp(r'EdgeInsets\.symmetric\(horizontal: 20[,)]|EdgeInsets\.fromLTRB\(20, [\w.+ ]+, 20, ');
    expect(_offenders(loose).where((hit) => hit.contains('/screens/')).toList(), isEmpty);
  });

  test('D-09: one back arrow', () {
    expect(_offenders(RegExp(r'Icons\.(arrow_back_ios|arrow_back\b(?!_)|chevron_left|keyboard_arrow_left)')), isEmpty);
  });
}
