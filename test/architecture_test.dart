import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// The dependency rule of the layers: presentation -> domain <- data.
//
// domain is plain Dart: entities, repository interfaces, use cases and pure
// logic. It imports no Flutter, Firebase, plugin, data or presentation
// code, so it can be tested (and reasoned about) on its own. data
// implements the domain's interfaces and never reaches into presentation.

/// Packages the domain may use: annotations for the generated JSON and
/// dependency injection code (plain Dart, no Flutter).
const _domainPackages = {
  'freezed_annotation',
  'json_annotation',
  'injectable',
  'meta',
  'collection',
};

final _import = RegExp(r"^(?:import|export)\s+'([^']+)'", multiLine: true);

/// The Dart files under `lib/dir`, generated parts aside, relative to lib/.
List<String> _dartFiles(String dir) => Directory('lib/$dir')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => p.relative(f.path, from: 'lib').replaceAll(r'\', '/'))
    .where((f) => f.endsWith('.dart') && !f.endsWith('.g.dart') && !f.endsWith('.freezed.dart'))
    .toList()
  ..sort();

/// Each import of [file] (relative to lib/): a lib/ path for the app's own
/// files, or the raw uri (dart:x, package:x/...) for the rest.
List<String> _imports(String file) {
  final source = File('lib/$file').readAsStringSync();
  return [
    for (final m in _import.allMatches(source))
      if (m.group(1)!.startsWith('package:tsuki_tunes_mobile/'))
        m.group(1)!.substring('package:tsuki_tunes_mobile/'.length)
      else if (m.group(1)!.contains(':'))
        m.group(1)!
      else
        p.normalize(p.join(p.dirname(file), m.group(1)!)).replaceAll(r'\', '/'),
  ];
}

bool _isPureDart(String uri) =>
    uri.startsWith('dart:') && !const {'dart:ui', 'dart:io', 'dart:html'}.contains(uri);

void main() {
  test('the domain is plain Dart that depends on nothing outside it', () {
    final offenders = <String>[];
    for (final file in _dartFiles('domain')) {
      for (final uri in _imports(file)) {
        final ok = _isPureDart(uri) ||
            (uri.startsWith('package:') && _domainPackages.contains(uri.split('/').first.substring(8))) ||
            uri.startsWith('domain/') ||
            // Shared kernel: core files that are plain Dart themselves.
            (uri.startsWith('core/') && _imports(uri).every(_isPureDart));
        if (!ok) offenders.add('$file -> $uri');
      }
    }
    expect(offenders, isEmpty);
  });

  test('data never reaches into presentation', () {
    final offenders = [
      for (final file in _dartFiles('data'))
        for (final uri in _imports(file))
          if (uri.startsWith('presentation/')) '$file -> $uri',
    ];
    expect(offenders, isEmpty);
  });

  test('no screen or widget calls a data source directly', () {
    final usingData = [
      for (final dir in ['presentation/screens', 'presentation/widgets'])
        for (final file in _dartFiles(dir))
          for (final uri in _imports(file))
            if (uri.startsWith('data/')) '$file -> $uri',
    ];
    expect(usingData, isEmpty,
        reason: 'go through a use case in domain/usecases, or a provider in '
            'presentation/state, instead');
  });
}
