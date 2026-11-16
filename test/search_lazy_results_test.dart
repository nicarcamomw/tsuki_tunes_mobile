import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/search_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/search_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/test_scope.dart';

// 120 fps: a search brings dozens of songs; building all their rows in the
// frame the results arrive stuttered. They're built as they scroll in.

final _songs = [
  for (var i = 0; i < 60; i++)
    Track(
      id: '$i',
      title: 'Song $i',
      artistId: 'a',
      artistName: 'Artist',
      albumId: 'b',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 200,
    ),
];

class _Results extends SearchProvider {
  _Results() : super(fuzzyArtistNames: (_) async => const []);
  @override
  String get query => 'song';
  @override
  bool get isLoading => false;
  @override
  bool get hasError => false;
  @override
  List<Artist> get artists => const [];
  @override
  List<Track> get tracks => _songs;
  @override
  List<Album> get albums => const [];
}

void main() {
  testWidgets('sixty songs found: only the rows on screen are built, the rest as they scroll in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          audioProvider.overrideWith((ref) => AudioProvider()),
          searchProvider.overrideWith((ref) => _Results()),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final built = find.byType(TrackTile, skipOffstage: false).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(30), reason: 'not all sixty at once');

      // Further down, the later ones come.
      await tester.scrollUntilVisible(find.text('Song 59'), 400, scrollable: find.byType(Scrollable).last);
      expect(find.text('Song 59'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  });
}
