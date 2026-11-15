import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';

// D-13: times and counts in figures of one width, so a ticking clock or a
// growing number doesn't shift what's around it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a tabular style asks the font for figures of one width', (tester) async {
    final locale = LocaleProvider();
    expect(locale.getTextStyle(tabular: true).fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(locale.getTextStyle().fontFeatures, isNull);
  });

  test('every formatted time or count is drawn tabular', () {
    final missing = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'Formatters\.format(Seconds|Duration|Number)\(').hasMatch(lines[i])) continue;
        if (!lines.skip(i).take(10).any((l) => l.contains('tabular: true'))) missing.add('${f.path}:${i + 1}');
      }
    }
    expect(missing, isEmpty);
  });
}
