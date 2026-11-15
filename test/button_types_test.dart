import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/core/theme/cyber_theme.dart';
import 'package:tsuki_tunes_mobile/core/theme/design_tokens.dart';

// D-10: three kinds of button. Primary: FilledButton (the red fill, for a
// screen's main action). Secondary: OutlinedButton (a quiet outline).
// Text: TextButton (no box). All take their corner and their 48 dp from
// the theme.

Iterable<(String, String)> _sources() sync* {
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) yield (f.path, f.readAsStringSync());
  }
}

void main() {
  test('only the three kinds: no ElevatedButton, no CyberButton', () {
    final found = [
      for (final (path, src) in _sources())
        if (RegExp(r'\bElevatedButton\b|\bCyberButton\b').hasMatch(src)) path,
    ];
    expect(found, isEmpty, reason: 'use FilledButton (primary) or OutlinedButton (secondary)');
  });

  test('a text button never wears a border: that is a secondary button', () {
    final found = <String>[];
    for (final (path, src) in _sources()) {
      for (final m in RegExp(r'TextButton\.styleFrom\(').allMatches(src)) {
        final call = src.substring(m.start, (m.start + 500).clamp(0, src.length));
        final end = call.indexOf('\n              )');
        final body = end < 0 ? call : call.substring(0, end);
        if (body.contains('side:')) found.add(path);
      }
    }
    expect(found, isEmpty);
  });

  test('buttons keep the theme\'s corner', () {
    final found = <String>[];
    final style = RegExp(r'(Filled|Outlined|Text)Button\.styleFrom\(');
    for (final (path, src) in _sources()) {
      for (final m in style.allMatches(src)) {
        // The call's arguments, up to its closing parenthesis.
        var depth = 0, i = m.end - 1;
        for (; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')' && --depth == 0) break;
        }
        if (RegExp(r'AppRadius\.(card|sheet)').hasMatch(src.substring(m.start, i))) found.add(path);
      }
    }
    expect(found, isEmpty, reason: 'the theme gives every button the chip corner');
  });

  testWidgets('the theme defines the three: red fill, neutral outline, red text', (tester) async {
    final theme = CyberTheme.darkTheme;
    final filled = theme.filledButtonTheme.style!;
    expect(filled.backgroundColor!.resolve({}), AppColors.accentFill);
    final outlined = theme.outlinedButtonTheme.style!;
    expect(outlined.side!.resolve({})!.color, AppColors.borderGlow);
    expect(theme.textButtonTheme.style!.foregroundColor!.resolve({}), AppColors.accentText);
    for (final s in [filled, outlined, theme.textButtonTheme.style!]) {
      final shape = s.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppRadius.chip));
      expect(s.tapTargetSize, MaterialTapTargetSize.padded);
    }
  });
}
