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

import 'helpers/test_scope.dart';

// B-04: the best match leads the "All" results.

const _artist = Artist(id: '27', name: 'Daft Punk', pictureUrl: '');
const _song = Track(
  id: '1',
  title: 'One More Time',
  artistId: '27',
  artistName: 'Daft Punk',
  albumId: 'b',
  albumTitle: 'Discovery',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 320,
);

class _Results extends SearchProvider {
  _Results(this._q) : super(fuzzyArtistNames: (_) async => const []);
  final String _q;
  @override
  String get query => _q;
  @override
  bool get isLoading => false;
  @override
  bool get hasError => false;
  @override
  List<Artist> get artists => const [_artist];
  @override
  List<Track> get tracks => const [_song];
  @override
  List<Album> get albums => const [];
}

final _deezer = MockClient((_) async => http.Response('{"data":[]}', 200));

void main() {
  Future<void> pump(WidgetTester tester, String query) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          audioProvider.overrideWith((ref) => AudioProvider()),
          searchProvider.overrideWith((ref) => _Results(query)),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }, () => _deezer);
  }

  testWidgets('typing an artist\'s name puts the artist first', (tester) async {
    await pump(tester, 'daft');
    expect(find.text('MEJOR RESULTADO'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('MEJOR RESULTADO: Daft Punk')), findsOneWidget);
  });

  testWidgets('otherwise the first song leads', (tester) async {
    await pump(tester, 'one more time');
    expect(find.text('MEJOR RESULTADO'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('MEJOR RESULTADO: Daft Punk')), findsNothing);
    // The song shows as the top result and again in the songs list.
    expect(find.text('One More Time'), findsNWidgets(2));
  });
}
