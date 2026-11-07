import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/music_catalog.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/discovery_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/discovery_controller.dart';

import 'helpers/test_scope.dart';

class _Catalog implements MusicCatalog {
  @override
  Future<List<Track>> getLargeChartTracks() async => [
        for (var i = 0; i < 8; i++)
          Track(
            id: 'c$i',
            title: 'Una canción con un título bastante largo número $i',
            artistName: 'Artista $i',
            artistId: 'a$i',
            albumId: 'al',
            albumTitle: 'Album',
            coverUrl: '',
            previewUrl: 'https://p/$i.mp3',
            durationSeconds: 200,
          ),
      ];

  @override
  Future<List<Artist>> getRelatedArtists(String artistId, {int limit = 20, bool throwOnError = false}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a song card with its three answers fits a small phone; passing shows the next', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final deck = DiscoveryController(
      catalog: _Catalog(),
      knownArtists: () => const [],
      topArtistNames: () => const [],
      isListened: (_) => false,
      random: Random(2),
    );
    await deck.start();
    final firstTitle = deck.cards.first.track.title;
    await tester.pumpWidget(TestScope(
      overrides: [discoveryProvider.overrideWith((ref) => deck)],
      child: const MaterialApp(home: DiscoveryScreen()),
    ));
    await tester.pump();
    expect(find.text(firstTitle), findsOneWidget);
    expect(find.bySemanticsLabel('Pasar'), findsOneWidget);
    expect(find.bySemanticsLabel('Guardar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Pasar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text(firstTitle), findsNothing);
    expect(deck.skipped, 1);
    expect(tester.takeException(), isNull);
  });
}
