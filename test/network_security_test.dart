import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards how the app connects (see the comment in
/// android/app/src/main/res/xml/network_security_config.xml): a change that
/// opens plain HTTP or trusts user-installed certificates fails here.
void main() {
  final release = File('android/app/src/main/res/xml/network_security_config.xml')
      .readAsStringSync();
  final debug = File('android/app/src/debug/res/xml/network_security_config.xml')
      .readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  String withoutComments(String xml) => xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  test('release builds use HTTPS only', () {
    expect(withoutComments(release), isNot(contains('cleartextTrafficPermitted="true"')));
    expect(withoutComments(release), contains('<base-config cleartextTrafficPermitted="false">'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
  });

  test('only Android\'s own certificate authorities are trusted', () {
    for (final xml in [release, debug]) {
      expect(withoutComments(xml), isNot(contains('src="user"')));
      expect(withoutComments(xml), isNot(contains('<debug-overrides')));
    }
  });

  test('debug builds open plain HTTP to this device only (the emulators)', () {
    final open = RegExp(r'<domain-config cleartextTrafficPermitted="true">(.*?)</domain-config>',
            dotAll: true)
        .allMatches(withoutComments(debug))
        .map((m) => m.group(1)!)
        .join();
    final domains = RegExp(r'>([^<]+)</domain>').allMatches(open).map((m) => m.group(1)).toSet();
    expect(domains, {'127.0.0.1', 'localhost'});
  });

  test('no code accepts a certificate that fails validation', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(r'badCertificateCallback|HttpOverrides').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
