import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// The dependency rule of the layers: presentation -> domain <- data.
//
// domain is plain Dart: entities, repository interfaces, use cases and pure
// logic. It imports no Flutter, Firebase, plugin, data or presentation
// code, so it can be tested (and reasoned about) on its own. data
// implements the domain's interfaces and never reaches into presentation.

/// Screens and widgets that still call a data source directly (mostly the
/// Deezer catalog) instead of a use case. Known debt: this list may only
/// shrink. A new screen or widget must go through the domain.
const _presentationToDataDebt = {
  'presentation/screens/album_detail_screen.dart',
  'presentation/screens/artist_detail_screen.dart',
  'presentation/screens/artist_discography_screen.dart',
  'presentation/screens/expanded_player_screen.dart',
  'presentation/screens/guess_song_screen.dart',
  'presentation/screens/home_screen.dart',
  'presentation/screens/library_screen.dart',
  'presentation/screens/login/login_screen.dart',
  'presentation/screens/main_navigation_screen.dart',
  'presentation/screens/onboarding/onboarding_screen.dart',
  'presentation/screens/playlist_detail_screen.dart',
  'presentation/screens/rabbit_hole_screen.dart',
  'presentation/screens/release_radar_screen.dart',
  'presentation/screens/search_screen.dart',
  'presentation/screens/time_machine_screen.dart',
  'presentation/screens/wrapped_screen.dart',
  'presentation/widgets/battery_guide_sheet.dart',
  'presentation/widgets/flow_sheet.dart',
  'presentation/widgets/language_selector_sheet.dart',
  'presentation/widgets/lyrics_view.dart',
  'presentation/widgets/moon_sheet.dart',
  'presentation/widgets/playlist_selector_sheet.dart',
  'presentation/widgets/profile_bottom_sheet.dart',
  'presentation/widgets/queue_panel.dart',
  'presentation/widgets/rinnegan_visualizer.dart',
  'presentation/widgets/sky_line.dart',
  'presentation/widgets/voice_search_sheet.dart',
  'presentation/widgets/weather_sheet.dart',
  'presentation/widgets/wrapped_picker_sheet.dart',
};

/// Packages the domain may use: annotations for the generated JSON code.
const _domainPackages = {'freezed_annotation', 'json_annotation', 'meta', 'collection'};

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

  test('no new screen or widget calls a data source directly', () {
    final usingData = {
      for (final dir in ['presentation/screens', 'presentation/widgets'])
        for (final file in _dartFiles(dir))
          if (_imports(file).any((uri) => uri.startsWith('data/'))) file,
    };
    expect(usingData.difference(_presentationToDataDebt), isEmpty,
        reason: 'go through a use case in domain/usecases instead');
    // Paying the debt down: drop the file from the list once it's clean.
    expect(_presentationToDataDebt.difference(usingData), isEmpty,
        reason: 'these no longer use data: remove them from the list');
  });
}
