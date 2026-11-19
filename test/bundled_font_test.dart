import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/core/theme/app_fonts.dart';
import 'package:tsuki_tunes_mobile/core/theme/cyber_theme.dart';

// The app's text font ships with it (pubspec fonts:), so the engine has it
// before the first frame. Through google_fonts it came from the network (or
// the disk) a moment after start: the entrance and the login were first
// drawn in a fallback font, then laid out again.
void main() {
  test('Plus Jakarta Sans is declared with the app, every weight it uses', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- family: ${AppFonts.jakarta}'));
    for (final w in [200, 300, 400, 500, 600, 700, 800]) {
      final asset = 'assets/fonts/plus_jakarta_sans_$w.ttf';
      expect(pubspec, contains('- asset: $asset\n          weight: $w'), reason: '$w');
      expect(File(asset).lengthSync(), greaterThan(30000), reason: asset);
    }
    expect(File('assets/fonts/plus_jakarta_sans_OFL.txt').existsSync(), isTrue, reason: 'its licence');
  });

  test('nothing asks google_fonts for it any more, and the theme uses it', () {
    final callers = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && f.readAsStringSync().contains('GoogleFonts.plusJakartaSans')) f.path,
    ];
    expect(callers, isEmpty);
    expect(CyberTheme.darkTheme.textTheme.bodyMedium?.fontFamily, AppFonts.jakarta);
  });
}
