import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The launcher icon: the login's mask (tool/app_icon/make_icons.py), under
// a resource name of its own so launchers that cache icons load it again.
void main() {
  test('the manifest points at the icon, and every density of it exists', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher_tsuki"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_tsuki"'));
    const res = 'android/app/src/main/res';
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final name in ['ic_launcher_tsuki', 'ic_launcher_tsuki_foreground', 'ic_launcher_monochrome']) {
        expect(File('$res/mipmap-$d/$name.png').existsSync(), isTrue, reason: '$d/$name');
      }
    }
    final adaptive = File('$res/mipmap-anydpi-v26/ic_launcher_tsuki.xml').readAsStringSync();
    expect(adaptive, contains('@mipmap/ic_launcher_tsuki_foreground'));
    expect(adaptive, contains('@mipmap/ic_launcher_monochrome'));
  });
}
