import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/repositories/music_catalog.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/home_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/main_navigation_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/use_cases.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/skeleton_loader.dart';

import 'helpers/test_scope.dart';

// I-01 / I-02: the home shows the last one saved at once, and a refresh
// keeps what's on screen while it loads.

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A catalog whose featured artists answer when the test says so.
class _Catalog implements MusicCatalog {
  Completer<List<Artist>> featured = Completer();
  int featuredCalls = 0;

  @override
  Future<List<Artist>> getFeaturedArtists() {
    featuredCalls++;
    return featured.future;
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 25}) async => const [];

  @override
  Future<List<Album>> getArtistAlbums(String artistId, {int limit = 250, int index = 0}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const []);
}

const _saved = Artist(id: '27', name: 'Daft Punk', pictureUrl: '');
const _fresh = Artist(id: '99', name: 'Justice', pictureUrl: '');

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  late _Catalog catalog;

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    final tmp = Directory.systemTemp.createTempSync('home_load');
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => tmp.path);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  late LibraryRepositoryImpl library;

  Future<void> pumpHome(WidgetTester tester) async {
    // Made inside the test's fake time, so its futures complete there.
    catalog = _Catalog();
    library = LibraryRepositoryImpl();
    tester.view.physicalSize = const Size(420 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestScope(
      overrides: [
        libraryProvider.overrideWith((ref) => library),
        audioProvider.overrideWith((ref) => AudioProvider()),
        connectivityProvider.overrideWith((ref) => _Online()),
        musicCatalogProvider.overrideWithValue(catalog),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the last home saved shows at once, without the skeleton', (tester) async {
    SharedPreferences.setMockInitialValues({
      'home_snapshot_v1': jsonEncode({
        'featured': [_saved.toJson()],
        'top': {},
        'releases': [],
      }),
    });
    await http.runWithClient(() async {
      await pumpHome(tester);
      // The catalog hasn't answered, yet the home has its artists.
      expect(catalog.featured.isCompleted, isFalse);
      expect(find.text('Daft Punk'), findsWidgets);
      expect(find.byType(HomeSkeletonLoader), findsNothing);

      // When it answers, the fresh home replaces it and is saved.
      catalog.featured.complete([_fresh]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Justice'), findsWidgets);
      expect(find.text('Daft Punk'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_snapshot_v1'), contains('Justice'));
      await leave(tester);
    }, () => _noNetwork);
  });

  testWidgets('with nothing saved the first load shows the skeleton', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await pumpHome(tester);
      expect(find.byType(HomeSkeletonLoader), findsOneWidget);
      catalog.featured.complete([_fresh]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(HomeSkeletonLoader), findsNothing);
      await leave(tester);
    }, () => _noNetwork);
  });

  testWidgets('pull to refresh keeps the home on screen while it reloads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await pumpHome(tester);
      catalog.featured.complete([_fresh]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Justice'), findsWidgets);

      // The refresh's request hangs: the content stays, no skeleton.
      catalog.featured = Completer();
      NavigationEvents.onHomeRefresh!();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(catalog.featuredCalls, 2);
      expect(find.byType(HomeSkeletonLoader), findsNothing);
      expect(find.text('Justice'), findsWidgets);

      // A failed refresh keeps it too (no error screen over it).
      catalog.featured.completeError(Exception('offline'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Justice'), findsWidgets);
      await leave(tester);
    }, () => _noNetwork);
  });

  testWidgets('the top artists follow the ranking: a library that loads late, and new points', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      await pumpHome(tester);
      catalog.featured.complete([_fresh]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Eladio Carrion'), findsNothing, reason: 'the library had not loaded yet');

      // The library finishes loading after the home: the top shows up on its
      // own, without reloading the rest of the home.
      ListenedTrackData song(String id) => ListenedTrackData(
          trackId: id, title: 'S$id', artistName: 'Eladio Carrion', albumTitle: '', albumId: '',
          coverUrl: '', previewUrl: '', duration: 200);
      await tester.runAsync(() => library.setListenedTracksForTesting([song('1'), song('2')]));
      library.notifyListeners(); // as the real load does when it's in
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Eladio Carrion'), findsWidgets);
      expect(find.text('Afinidad: 4'), findsOneWidget);
      expect(catalog.featuredCalls, 1);

      // What really played adds to the points, live.
      library.setArtistPlays({'Eladio Carrion': 30});
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Afinidad: 34'), findsOneWidget);
      await leave(tester);
    }, () => _noNetwork);
  });
}
