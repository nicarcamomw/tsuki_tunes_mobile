import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/library_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';

import 'helpers/test_scope.dart';

// L-01: a big library (5000 songs in 500 albums) builds only what's on
// screen, and pages in more as it scrolls.

class _BigLibrary extends LibraryRepositoryImpl {
  _BigLibrary(this._tracks);
  final List<ListenedTrackData> _tracks;
  @override
  List<ListenedTrackData> get listenedTracks => _tracks;
  @override
  int get listenedCount => _tracks.length;
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

bool _isAlbumRow(Widget w) => w.runtimeType.toString() == '_AlbumGroupTile';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
  });

  testWidgets('5000 songs: only the visible albums are built, the rest page in on scroll', (tester) async {
    final start = DateTime(2026);
    final tracks = [
      for (var a = 0; a < 500; a++)
        for (var t = 0; t < 10; t++)
          ListenedTrackData(
            trackId: 'a$a-t$t',
            title: 'Canción $t',
            artistName: 'Artista ${a % 80}',
            albumTitle: 'Álbum $a',
            albumId: 'album$a',
            coverUrl: '',
            previewUrl: '',
            duration: 200,
            listenedAt: start.add(Duration(minutes: a * 10 + t)),
          ),
    ];
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => _BigLibrary(tracks)),
          audioProvider.overrideWith((ref) => AudioProvider()),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final built = find.byWidgetPredicate(_isAlbumRow).evaluate().length;
      expect(built, greaterThan(3));
      expect(built, lessThan(30), reason: 'a lazy list builds about a screenful, not 500 albums');
      expect(find.text('Álbum 499'), findsOneWidget, reason: 'most recent first');

      // Each time the end of a page comes near, the next 50 load.
      for (var i = 0; i < 40; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Ten pages later, the oldest album is reached.
      expect(find.text('Álbum 0'), findsOneWidget);
      expect(find.byWidgetPredicate(_isAlbumRow).evaluate().length, lessThan(30));
    }, () => _noNetwork);
  });
}
