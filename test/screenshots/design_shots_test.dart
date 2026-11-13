@Tags(['shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/core/theme/cyber_theme.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/profile_repository_impl.dart';
import 'package:tsuki_tunes_mobile/data/repositories/social_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/album.dart';
import 'package:tsuki_tunes_mobile/domain/entities/artist.dart';
import 'package:tsuki_tunes_mobile/domain/entities/social.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/album_detail_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/artist_detail_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/bonds_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/eco_levels_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/home_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/library_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/lore_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/main_navigation_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/mask_collection_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/search_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/streak_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/state/search_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/social_controller.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/app_snack.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/error_state.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/profile_bottom_sheet.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/queue_panel.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import '../helpers/fake_firebase_service.dart';
import '../helpers/test_scope.dart';

// Screenshots of the main screens with the real fonts, for the "before and
// after" of every visual change (rule 5 of the polish plan).
//
//   TSUKI_SHOTS=/some/folder TSUKI_SHOT_FONTS=/folder/with/fonts \
//     flutter test --tags shots test/screenshots
//
// TSUKI_SHOT_FONTS holds PlusJakartaSans-400.ttf … -800.ttf and
// NotoSansJP-Regular.otf / -Bold.otf; without it Roboto (bundled with
// Flutter) stands in. Without TSUKI_SHOTS nothing runs.

final _outDir = Platform.environment['TSUKI_SHOTS'];
final _fontDir = Platform.environment['TSUKI_SHOT_FONTS'];

const _song = Track(
  id: '1',
  title: 'Get Lucky',
  artistId: 'a',
  artistName: 'Daft Punk',
  albumId: 'b',
  albumTitle: 'Random Access Memories',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 248,
);

class _StillAudio extends AudioProvider {
  @override
  Track? get currentTrack => _song;
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _upNext = [
  Track(id: '2', title: 'Instant Crush', artistId: 'a', artistName: 'Daft Punk', albumId: 'b',
      albumTitle: 'Random Access Memories', coverUrl: '', previewUrl: '', durationSeconds: 337),
  Track(id: '3', title: 'Lose Yourself to Dance', artistId: 'a', artistName: 'Daft Punk', albumId: 'b',
      albumTitle: 'Random Access Memories', coverUrl: '', previewUrl: '', durationSeconds: 353),
  Track(id: '4', title: 'Doin\' it Right', artistId: 'a', artistName: 'Daft Punk', albumId: 'b',
      albumTitle: 'Random Access Memories', coverUrl: '', previewUrl: '', durationSeconds: 251),
];

/// A queue with the song playing and three up next.
class _QueueAudio extends _StillAudio {
  @override
  List<Track> get queue => const [_song, ..._upNext];
  @override
  int get currentIndex => 0;
  @override
  List<int> upcomingOrder([int max = 60]) => const [1, 2, 3];
  @override
  int get upcomingCount => 3;
  @override
  List<Track> get upcomingTracks => _upNext;
}

/// Deezer as a screen sees it: two genres, nothing else. The fonts never
/// answer.
final _deezer = MockClient((req) async {
  if (req.url.host != 'api.deezer.com') return Completer<http.Response>().future;
  if (req.url.path == '/genre') {
    return http.Response(
        '{"data":[{"id":0,"name":"Todos"},{"id":116,"name":"Rap/Hip Hop"},'
        '{"id":152,"name":"Rock"},{"id":132,"name":"Pop"}]}',
        200);
  }
  return http.Response('{"data":[]}', 200);
});

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async => ByteData.sublistView(await File(path).readAsBytes());

  final icons = FontLoader('MaterialIcons')..addFont(read('$material/MaterialIcons-Regular.otf'));
  await icons.load();

  final latin = <String>[];
  final jp = <String>[];
  if (_fontDir != null && File('$_fontDir/PlusJakartaSans-400.ttf').existsSync()) {
    for (final w in [400, 500, 600, 700, 800]) {
      latin.add('$_fontDir/PlusJakartaSans-$w.ttf');
    }
    jp
      ..add('$_fontDir/NotoSansJP-Regular.otf')
      ..add('$_fontDir/NotoSansJP-Bold.otf');
  } else {
    latin.addAll(['$material/Roboto-Regular.ttf', '$material/Roboto-Medium.ttf', '$material/Roboto-Bold.ttf']);
  }

  // google_fonts names a family per weight ("PlusJakartaSans_700") and
  // falls back to the bare name; the theme uses "_regular".
  const variants = ['', '_regular', '_italic', '_100', '_200', '_300', '_500', '_600', '_700', '_800', '_900'];
  for (final family in ['PlusJakartaSans', 'Roboto', 'Exo2', 'Orbitron']) {
    for (final v in variants) {
      final loader = FontLoader('$family$v');
      for (final f in latin) {
        loader.addFont(read(f));
      }
      await loader.load();
    }
  }
  for (final family in ['NotoSansJP', 'NotoSansJapanese']) {
    for (final v in variants) {
      final loader = FontLoader('$family$v');
      for (final f in jp.isEmpty ? latin : jp) {
        loader.addFont(read(f));
      }
      await loader.load();
    }
  }
}

final _boundary = GlobalKey();

Future<void> _shoot(WidgetTester tester, String name) async {
  final dir = Directory(_outDir!)..createSync(recursive: true);
  final obj = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await obj.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pumpShot(
  WidgetTester tester,
  String name,
  Widget child, {
  List<Override> overrides = const [],
  bool scaffold = false,
}) async {
  tester.view.physicalSize = const Size(400 * 2, 860 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // A layout overflow still gets its picture taken (that's what it's for).
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  await http.runWithClient(() async {
    await tester.pumpWidget(RepaintBoundary(
      key: _boundary,
      child: TestScope(
        overrides: [
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
          ...overrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CyberTheme.darkTheme,
          home: scaffold ? Scaffold(backgroundColor: AppColors.bgDeep, body: child) : child,
        ),
      ),
    ));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }, () => _deezer);
  await _shoot(tester, name);
  if (errors.isNotEmpty) {
    // ignore: avoid_print
    print('[$name] ${errors.toSet().join(' | ')}');
  }
  // Leave no timers behind: unmount and let animations settle.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  FlutterError.onError = previous;
}

void main() {
  final skip = _outDir == null ? 'set TSUKI_SHOTS=<folder> to take the screenshots' : null;

  setUpAll(() async {
    if (_outDir != null) await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'search_history': ['metallica', 'daft punk']});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    // Covers go through the image cache, which wants a folder.
    final tmp = Directory.systemTemp.createTempSync('shots');
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

  final base = <Override>[
    libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
    connectivityProvider.overrideWith((ref) => _Online()),
  ];

  testWidgets('widgets', skip: skip != null, (tester) async {
    await _pumpShot(
      tester,
      'widgets',
      scaffold: true,
      overrides: [...base, audioProvider.overrideWith((ref) => _StillAudio())],
      SafeArea(
        child: Column(children: [
          const TrackTile(track: _song, index: 1, showListenedCheckbox: true),
          const TrackTile(track: _song, index: 2),
          const SizedBox(height: 24),
          SizedBox(height: 260, child: ErrorState(message: 'No se pudo cargar', onRetry: () {})),
          const Spacer(),
          const MiniPlayer(),
        ]),
      ),
    );
  });

  testWidgets('shell', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'shell', overrides: [...base, audioProvider.overrideWith((ref) => _StillAudio())],
        const MainNavigationScreen(child: SizedBox.expand()));
  });

  testWidgets('shell_snack', skip: skip != null, (tester) async {
    await _pumpShot(
      tester,
      'shell_snack',
      overrides: [...base, audioProvider.overrideWith((ref) => _StillAudio())],
      MainNavigationScreen(
        child: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) AppSnack.of(context).undo('Desmarcada: Get Lucky', onUndo: () {});
          });
          return const SizedBox.expand();
        }),
      ),
    );
  });

  testWidgets('album', skip: skip != null, (tester) async {
    await _pumpShot(
      tester,
      'album',
      overrides: [...base, audioProvider.overrideWith((ref) => AudioProvider())],
      const AlbumDetailScreen(
        album: Album(
          id: '302127',
          title: 'Discovery',
          artistId: '27',
          artistName: 'Daft Punk',
          coverUrl: '',
          tracks: [_song],
          tracksCount: 1,
        ),
      ),
    );
  });

  testWidgets('artist', skip: skip != null, (tester) async {
    await _pumpShot(
      tester,
      'artist',
      overrides: [...base, audioProvider.overrideWith((ref) => AudioProvider())],
      const ArtistDetailScreen(artist: Artist(id: '27', name: 'Daft Punk', pictureUrl: '')),
    );
  });

  testWidgets('home', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'home', overrides: [...base, audioProvider.overrideWith((ref) => AudioProvider())],
        const HomeScreen());
  });

  testWidgets('search', skip: skip != null, (tester) async {
    await _pumpShot(
      tester,
      'search',
      overrides: [
        ...base,
        audioProvider.overrideWith((ref) => AudioProvider()),
        searchProvider.overrideWith((ref) => SearchProvider(fuzzyArtistNames: (_) async => const [])),
      ],
      const SearchScreen(),
    );
  });

  testWidgets('library', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'library', overrides: [...base, audioProvider.overrideWith((ref) => AudioProvider())],
        const LibraryScreen());
  });

  testWidgets('queue', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'queue', scaffold: true,
        overrides: [...base, audioProvider.overrideWith((ref) => _QueueAudio())], const QueuePanel());
  });

  testWidgets('profile', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'profile', scaffold: true,
        overrides: [...base, audioProvider.overrideWith((ref) => AudioProvider())],
        Consumer(builder: (context, ref, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
              ProfileBottomSheet.show(context, ref.read(authProvider));
            }
          });
          return const SizedBox.expand();
        }));
  });

  testWidgets('lore', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'lore', overrides: base, const LoreScreen());
  });

  testWidgets('streak', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'streak', overrides: base, const StreakScreen());
  });

  testWidgets('eco', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'eco', overrides: base, const EcoLevelsScreen());
  });

  testWidgets('masks', skip: skip != null, (tester) async {
    await _pumpShot(tester, 'masks', overrides: base, const MaskCollectionScreen());
  });

  testWidgets('bonds', skip: skip != null, (tester) async {
    final db = FakeFirebaseFirestore();
    final at = DateTime(2026, 11, 7);
    await db.doc('users/me/friendRequests/alice').set({'name': 'Alice', 'at': at});
    await db.doc('users/me/friends/carol').set({'name': 'Carol', 'at': at});
    final social = SocialController(
      repository: SocialRepositoryImpl(FakeFirebaseService(db)),
      profiles: ProfileRepositoryImpl(FakeFirebaseService(db)),
      changes: ChangeNotifier(),
      uid: () => 'me',
      myCard: () => const SocialPerson(uid: 'me', name: 'Nico'),
      myTops: () => const [],
    );
    await _pumpShot(tester, 'bonds', overrides: [...base, socialProvider.overrideWith((ref) => social)],
        const BondsScreen(initialTab: 1));
  });
}
