import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Emoji, by their blocks: pictographs, symbols and their variation
/// selector. Arrows, dots and other text symbols are fine.
final _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2B50}\u{2B55}\u{FE0F}]',
  unicode: true,
);

/// Allowed text symbols inside those blocks (not drawn as emoji).
const _allowed = {'♪', '✦'};

void main() {
  test('the app shows no emoji: icons do that job', () {
    final offenders = <String>[];
    final files = [
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => (f.path.endsWith('.dart') || f.path.endsWith('.arb')) && !f.path.contains('/generated/')),
      ...Directory('android/app/src/main')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.kt') || f.path.endsWith('.xml')),
    ];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        final found = _emoji.allMatches(line).map((m) => m.group(0)!).where((c) => !_allowed.contains(c));
        if (found.isNotEmpty) offenders.add('${file.path}:${i + 1}: ${found.join()}');
      }
    }
    expect(offenders, isEmpty);
  });
}
