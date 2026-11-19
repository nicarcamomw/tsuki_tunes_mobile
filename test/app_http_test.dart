import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Requests go through AppHttp's one client, which keeps its connections
// open: the package's top-level functions open (and close) a connection,
// TCP and TLS, for every request.
void main() {
  test('no request uses the package\'s one-off top-level functions', () {
    final offenders = <String>[];
    final call = RegExp(r'\bhttp\.(get|post|put|patch|delete|head|read|readBytes)\(');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('app_http.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (call.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'use AppHttp');
  });
}
