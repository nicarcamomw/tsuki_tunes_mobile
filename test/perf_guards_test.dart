import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/main_navigation_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/tsuki_sky.dart';

import 'helpers/test_scope.dart';

// What made the app feel slow after the liquid glass, kept from coming back:
// a backdrop blur re-reads the screen every frame, and the dock is always
// on screen (every frame animates while a song plays); the entrance's
// nebula shader ran at full resolution 60 times a second.

const _song = Track(
  id: '1',
  title: 'Misis Guiñi',
  artistId: 'a',
  artistName: 'Tronic',
  albumId: 'b',
  albumTitle: 'Evoluciona',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 146,
);

class _Playing extends AudioProvider {
  @override
  Track? get currentTrack => _song;
  @override
  bool get isPlaying => true;
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  testWidgets('the dock, with a song playing, draws no backdrop blur', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => _Playing()),
          playerTintColorProvider.overrideWithValue(const Color(0xFFFFC83D)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: MainNavigationScreen(child: SizedBox.expand())),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(MainNavigationScreen.dockKey), findsOneWidget);
      expect(find.descendant(of: find.byKey(MainNavigationScreen.dockKey), matching: find.byType(BackdropFilter)),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _noNetwork);
  });

  testWidgets('a song playing runs no ticker: the cover breathes on a timer', (tester) async {
    // The mini player's cover breathed at the screen's rate for as long as
    // a song played: the whole app redrawn 60 times a second.
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => _Playing()),
          playerTintColorProvider.overrideWithValue(const Color(0xFFFFC83D)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: MainNavigationScreen(child: SizedBox.expand())),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Misis Guiñi'), findsWidgets);
      // No ticker runs (a ticker asks for every frame the screen has); the
      // cover's breath steps on a timer, 12 times a second.
      Color? border() {
        // The cover's frame: lit border and glow.
        final box = tester.widget<DecoratedBox>(find
            .descendant(
              of: find.byType(MiniPlayer),
              matching: find.byWidgetPredicate((w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).border != null &&
                  (w.decoration as BoxDecoration).boxShadow != null),
            )
            .first);
        return ((box.decoration as BoxDecoration).border! as Border).top.color;
      }
      expect(tester.binding.transientCallbackCount, 0, reason: 'the dock is on every screen');
      expect(MiniPlayer.breathing, 1);
      final before = border();
      await tester.pump(const Duration(milliseconds: 700));
      expect(border(), isNot(before), reason: 'the cover still breathes');
      expect(tester.binding.transientCallbackCount, 0);

      // Screen off, music on: its timer stops (a timer, unlike a ticker,
      // would keep waking the phone), and starts again when shown.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(MiniPlayer.breathing, 0, reason: 'nothing ticks in the background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(MiniPlayer.breathing, 1, reason: 'back on screen, it breathes again');
      final awake = border();
      await tester.pump(const Duration(milliseconds: 700));
      expect(border(), isNot(awake));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _noNetwork);
  });

  testWidgets('the nebula runs its shader 15 times a second at most, not every frame', (tester) async {
    final program = await tester.runAsync(() => tsukiNebulaProgram);
    if (program == null) return; // No shaders in this test engine: nothing to bake.
    final time = ValueNotifier<double>(0);
    final painter = NebulaPainter(program.fragmentShader(),
        time: time, intensity: const AlwaysStoppedAnimation(1), still: false);
    final before = NebulaPainter.bakes;
    // Two seconds at 60 fps.
    for (var f = 0; f < 120; f++) {
      time.value = f / 60;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(400, 860));
      recorder.endRecording().dispose();
    }
    final bakes = NebulaPainter.bakes - before;
    expect(bakes, lessThanOrEqualTo(2 * NebulaPainter.bakesPerSecond + 1));
    expect(bakes, greaterThan(0));
  });
}
