import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/library_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/album_track_order.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';

import 'helpers/test_scope.dart';

// The library plays an album in the album's order and goes on into the next
// albums of the list; the songs tab plays the songs under the one picked.

class _Library extends LibraryRepositoryImpl {
  _Library(this._tracks);
  final List<ListenedTrackData> _tracks;
  @override
  List<ListenedTrackData> get listenedTracks => _tracks;
  @override
  int get listenedCount => _tracks.length;
}

class _Service extends AudioPlayerService {
  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {}
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

ListenedTrackData _song(String id, String album, int minute) => ListenedTrackData(
      trackId: id,
      title: 'Song $id',
      artistName: 'Artist',
      albumTitle: 'Album $album',
      albumId: album,
      coverUrl: '',
      duration: 200,
      listenedAt: DateTime(2026, 11, 1).add(Duration(minutes: minute)),
    );

void main() {
  late AudioProvider audio;
  final masks = MaskProvider();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.${(call.arguments as Map)['id']}'), (_) async => {});
      }
      return {};
    });
    audio = AudioProvider(service: _Service(), storage: StorageService());
  });

  // Newest marked first, as the library keeps them. Album B was marked
  // last, so it's on top; its songs were marked out of order.
  final library = [
    _song('b1', 'B', 40),
    _song('b3', 'B', 39),
    _song('b2', 'B', 38),
    _song('a2', 'A', 11),
    _song('a1', 'A', 10),
  ];
  final albumOrders = {
    'A': ['a1', 'a2', 'a3'],
    'B': ['b1', 'b2', 'b3'],
  };

  Future<void> open(WidgetTester tester, {Size size = const Size(400, 860)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestScope(
      overrides: [
        libraryProvider.overrideWith((ref) => _Library(library)),
        audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
        // The song rows' masks load after the test; kept, not disposed.
        maskProvider.overrideWith((ref) => masks, disposeNotifier: false),
        albumTrackOrderProvider.overrideWith((ref) => AlbumTrackOrder(fetch: (id) async => albumOrders[id])),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets("an album opens in its order and plays on into the next album", (tester) async {
    await http.runWithClient(() async {
      await open(tester);
      await tester.tap(find.text('Album B'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final titles = tester.widgetList<Text>(find.textContaining('Song b')).map((t) => t.data).toList();
      expect(titles, ['Song b1', 'Song b2', 'Song b3'], reason: "the album's order, not the order marked");
      expect(find.text('2'), findsOneWidget, reason: 'each song shows its number on the album');

      await tester.tap(find.text('Song b2'));
      await tester.pumpAndSettle();
      expect(audio.currentTrack?.id, 'b2');
      expect(audio.queue.map((t) => t.id), ['b1', 'b2', 'b3', 'a1', 'a2'],
          reason: 'the rest of the album, then the next album in order');
      await audio.stop();
      await tester.pump(const Duration(seconds: 5));
    }, () => _noNetwork);
    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });

  testWidgets('the songs tab plays the song picked and the ones under it', (tester) async {
    await http.runWithClient(() async {
      await open(tester);
      await tester.tap(find.text('Canciones'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Song b3'));
      await tester.pumpAndSettle();
      expect(audio.currentTrack?.id, 'b3');
      expect(audio.queue.map((t) => t.id), ['b3', 'b2', 'a2', 'a1']);

      // The filter narrows the list.
      await tester.enterText(find.byType(TextField), 'a1');
      await tester.pumpAndSettle();
      expect(find.text('Song a1'), findsOneWidget);
      expect(find.text('Song b1'), findsNothing);
      await audio.stop();
      await tester.pump(const Duration(seconds: 5));
    }, () => _noNetwork);
    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });

  testWidgets('four tabs fit a small phone; artists has its own empty page', (tester) async {
    await http.runWithClient(() async {
      await open(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Artistas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget, reason: 'the filter is there for artists too');
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing, reason: 'playlists keep their own buttons');
      await audio.stop();
      await tester.pump(const Duration(seconds: 5));
    }, () => _noNetwork);
    await tester.pumpWidget(const SizedBox());
    audio.dispose();
  });
}
