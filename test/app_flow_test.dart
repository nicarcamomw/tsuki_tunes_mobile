// T6: the app's main path, end to end, through the real router, screens
// and providers: sign in, search, play, mark. Deezer answers from a stub,
// Firestore is in memory and the player plays nothing, so it runs in CI on
// every push for free (integration_test/app_smoke_test.dart, on a real
// phone in Test Lab, stays a run by hand).
//
// A guest is an Observer: they can search and listen but not mark songs,
// so marking is walked with a signed-in account.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/theme/cyber_theme.dart';
import 'package:tsuki_tunes_mobile/data/datasources/firebase_service.dart';
import 'package:tsuki_tunes_mobile/di/injection.dart';
import 'package:tsuki_tunes_mobile/presentation/navigation/app_router.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/auth_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/fake_firebase_service.dart';

const _uid = 'test-user';

Map<String, dynamic> _deezerTrack(int id, String title) => {
  'id': id,
  'title': title,
  'duration': 215,
  'rank': 900000,
  'preview': 'https://cdn.example/$id.mp3',
  'artist': {'id': 27, 'name': 'Daft Punk'},
  'album': {'id': 302127, 'title': 'Discovery', 'cover_medium': ''},
};

final _songs = [_deezerTrack(3135556, 'One More Time'), _deezerTrack(3135557, 'Aerodynamic')];

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Deezer, as far as this path needs it; the rest of the network (fonts,
/// the backend) never answers.
final _network = MockClient((req) async {
  if (req.url.host != 'api.deezer.com') return Completer<http.Response>().future;
  final path = req.url.path;
  if (path.startsWith('/search')) return _json({'data': _songs, 'total': _songs.length});
  if (path.startsWith('/track/')) {
    final id = int.parse(path.split('/').last);
    return _json(_songs.firstWhere((s) => s['id'] == id));
  }
  return _json({'data': []});
});

/// An account signed in with Google, without Firebase Auth.
class _SignedIn extends AuthProvider {
  _SignedIn({super.firebase});
  @override
  bool get loading => false;
  @override
  bool get isGuest => false;
  @override
  bool get isLoggedIn => true;
  @override
  bool get isAuthenticated => true;
  @override
  String? get uid => _uid;
  @override
  bool get isAdmin => false;
}

/// Always online (the plugin's stream isn't there in a test).
class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A song in the results' song list (an album can have the same title).
Finder _songRow(String title) => find.descendant(of: find.byType(TrackTile), matching: find.text(title)).first;

void main() {
  late FakeFirebaseFirestore server;

  setUp(() {
    SharedPreferences.setMockInitialValues({'tsuki_has_completed_onboarding': true});
    server = FakeFirebaseFirestore();
    getIt
      ..unregister<FirebaseService>()
      ..registerSingleton<FirebaseService>(FakeFirebaseService(server));
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    // Caches (disk cache, pre-downloads) get a folder of their own.
    final files = Directory.systemTemp.createTempSync('tsuki_app_flow_');
    addTearDown(() => files.deleteSync(recursive: true));
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => files.path,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        for (final stream in ['events', 'data']) {
          messenger.setMockStreamHandler(
            EventChannel('com.ryanheise.just_audio.$stream.$id'),
            MockStreamHandler.inline(onListen: (_, __) {}),
          );
        }
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (c) async {
          if (c.method == 'load') return {'duration': 30000000};
          return {};
        });
      }
      return {};
    });
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// The app as main.dart builds it, with the given overrides.
  Future<ProviderContainer> launch(WidgetTester tester, {AuthProvider? auth}) async {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWith((ref) => LocaleProvider()),
        connectivityProvider.overrideWith((ref) => _Online()),
        if (auth != null) authProvider.overrideWith((ref) => auth),
      ],
    );
    final router = createAppRouter(container.read(sessionGateProvider));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router, theme: CyberTheme.darkTheme),
      ),
    );
    await settle(tester);
    return container;
  }

  testWidgets('a guest signs in, searches and plays; marking is for accounts', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      SharedPreferences.setMockInitialValues({'tsuki_has_completed_onboarding': true});
      final app = await launch(tester);

      await tester.tap(find.text('ENTRAR COMO OBSERVADOR'));
      await settle(tester);
      expect(app.read(authProvider).isGuest, isTrue);

      await search(tester, 'daft punk');
      await tester.tap(_songRow('One More Time'));
      await settle(tester);

      final audio = app.read(audioProvider);
      expect(audio.currentTrack?.title, 'One More Time');
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.descendant(of: find.byType(MiniPlayer), matching: find.text('One More Time')), findsOneWidget);
      // An Observer has no mark to set.
      expect(find.bySemanticsLabel('Marcar como escuchada'), findsNothing);
      await leave(tester, app);
    }, () => _network);
  });

  testWidgets('an account searches, plays and marks the song', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      final app = await launch(tester, auth: _SignedIn(firebase: getIt<FirebaseService>()));

      await search(tester, 'daft punk');
      await tester.tap(_songRow('One More Time'));
      await settle(tester);
      expect(app.read(audioProvider).currentTrack?.id, '3135556');

      final mark = find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.bySemanticsLabel('Marcar como escuchada'),
      );
      expect(mark, findsOneWidget);
      await tester.tap(mark);
      await settle(tester);

      final library = app.read(libraryProvider);
      expect(library.isTrackListened('3135556'), isTrue);
      expect(
        find.descendant(of: find.byType(MiniPlayer), matching: find.bySemanticsLabel('Desmarcar como escuchada')),
        findsOneWidget,
      );
      await tester.runAsync(library.pendingWritesSentForTesting);
      final saved = await server.collection('users').doc(_uid).collection('listenedTracks').doc('3135556').get();
      expect(saved.exists, isTrue, reason: 'the mark reached the server');
      expect(saved.data()!['title'], 'One More Time');
      await leave(tester, app);
    }, () => _network);
  });
}

/// Real waits for the disk and isolates, alternating with frames (the app
/// has looping animations, so it never settles by itself).
Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Goes to the search tab and looks [query] up.
Future<void> search(WidgetTester tester, String query) async {
  await tester.tap(find.text('BUSCAR').last);
  await settle(tester);
  await tester.enterText(find.byType(TextField).first, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await settle(tester, rounds: 16);
}

/// Closes the app as the system would: the screens, then its providers
/// (their timers with them), and lets what's left run out.
Future<void> leave(WidgetTester tester, ProviderContainer app) async {
  // The player is one for the app's whole life (get_it), so it isn't the
  // container's to close: it goes by hand, with its audio players.
  final audio = app.read(audioProvider);
  await tester.pumpWidget(const SizedBox());
  app.dispose();
  audio.dispose();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(seconds: 30));
}
