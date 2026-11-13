// The bottom bar's four tabs (Home, Search, Explore, Library) through the
// real router and screens: Explore gathers what there is to do besides
// playing music, and Home keeps one card for today that leads there.
//
// With TSUKI_SHOTS set to a folder, the test also saves a picture of each
// screen there (drawn with the machine's own fonts, so close to the phone
// but not identical): `TSUKI_SHOTS=shots flutter test test/explore_tab_test.dart`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:tsuki_tunes_mobile/presentation/navigation/main_tab.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/explore_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/auth_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/locale_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/cyber_nav_icon.dart';

import 'helpers/fake_firebase_service.dart';

const _artistNames = ['Daft Punk', 'Radiohead', 'Gorillaz', 'Björk', 'Tame Impala', 'Arctic Monkeys'];

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Deezer with a few artists and nothing else; the rest of the network
/// (fonts, the backend) never answers.
final _network = MockClient((req) async {
  if (req.url.host != 'api.deezer.com') return Completer<http.Response>().future;
  final artist = RegExp(r'^/artist/(\d+)$').firstMatch(req.url.path);
  if (artist != null) {
    final id = int.parse(artist.group(1)!);
    return _json({'id': id, 'name': _artistNames[id % _artistNames.length], 'nb_fan': 1000 + id, 'picture_medium': ''});
  }
  return _json({'data': []});
});

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
  String? get uid => 'test-user';
  @override
  bool get isAdmin => false;
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _shots = Platform.environment['TSUKI_SHOTS'];
final _shotKey = GlobalKey();

/// The machine's fonts under the names the app asks google_fonts for, so a
/// picture has real letters and icons instead of the test font's boxes.
Future<void> _loadPictureFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }

  final root =
      Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  await load('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!Platform.isWindows) return;
  const fonts = r'C:\Windows\Fonts';
  for (final (variant, latin, japanese) in [
    ('regular', 'segoeui.ttf', 'YuGothR.ttc'),
    ('500', 'segoeui.ttf', 'YuGothM.ttc'),
    ('600', 'seguisb.ttf', 'YuGothB.ttc'),
    ('700', 'segoeuib.ttf', 'YuGothB.ttc'),
    ('800', 'segoeuib.ttf', 'YuGothB.ttc'),
    ('900', 'seguibl.ttf', 'YuGothB.ttc'),
  ]) {
    await load('PlusJakartaSans_$variant', '$fonts\\$latin');
    await load('NotoSansJP_$variant', '$fonts\\$japanese');
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_shots == null) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_shots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Real waits for the disk and isolates, alternating with frames (the app
/// has looping animations, so it never settles by itself).
Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(() async {
    if (_shots != null) await _loadPictureFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'tsuki_has_completed_onboarding': true});
    getIt
      ..unregister<FirebaseService>()
      ..registerSingleton<FirebaseService>(FakeFirebaseService(FakeFirebaseFirestore()));
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    final files = Directory.systemTemp.createTempSync('tsuki_explore_');
    addTearDown(() => files.deleteSync(recursive: true));
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => files.path,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  testWidgets('four tabs; Explore gathers discover, play and path; Home leads there', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleProvider()),
          connectivityProvider.overrideWith((ref) => _Online()),
          authProvider.overrideWith((ref) => _SignedIn(firebase: getIt<FirebaseService>())),
        ],
      );
      final router = createAppRouter(container.read(sessionGateProvider));
      await tester.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              theme: CyberTheme.darkTheme,
            ),
          ),
        ),
      );
      await _settle(tester, rounds: 20);

      // The bar: four tabs, in order.
      final icons = tester.widgetList<CyberNavIcon>(find.byType(CyberNavIcon)).map((i) => i.tab).toList();
      expect(icons, MainTab.values);
      for (final label in ['INICIO', 'BUSCAR', 'EXPLORAR', 'BIBLIOTECA']) {
        expect(find.text(label), findsWidgets);
      }

      // Home: one card for today, and the way to Explore.
      expect(find.text('HOY'), findsOneWidget);
      expect(find.byType(ExploreScreen), findsNothing, reason: 'built the first time it is opened');
      await _shot(tester, '1_inicio');

      // The heading's link opens the Explore tab.
      await tester.tap(find.widgetWithText(TextButton, 'EXPLORAR'));
      await _settle(tester);
      expect(find.byType(ExploreScreen), findsOneWidget);
      for (final section in ['MÚSICA NUEVA', 'JUGAR', 'TU CAMINO']) {
        expect(find.text(section), findsOneWidget);
      }
      await _shot(tester, '2_explorar');

      await tester.drag(find.byType(ListView).last, const Offset(0, -520));
      await _settle(tester, rounds: 6);
      await _shot(tester, '3_explorar_abajo');

      // The bar's own tab does the same from anywhere.
      await tester.tap(find.text('BIBLIOTECA').last);
      await _settle(tester);
      await _shot(tester, '4_biblioteca');
      await tester.tap(find.text('EXPLORAR').last);
      await _settle(tester);
      expect(tester.widget<CyberNavIcon>(find.byType(CyberNavIcon).at(MainTab.explore.index)).isSelected, isTrue);

      final audio = container.read(audioProvider);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      audio.dispose();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 30));
    }, () => _network);
  });
}
