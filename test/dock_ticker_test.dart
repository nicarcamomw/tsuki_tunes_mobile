import 'dart:async';

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

import 'helpers/test_scope.dart';

// R-04: when the dock (mini player + bar) slides away, its animations stop.

const _song = Track(
  id: '1',
  title: 'Get Lucky',
  artistId: 'a',
  artistName: 'Daft Punk',
  albumId: 'b',
  albumTitle: 'RAM',
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

  bool miniPlayerTicks(WidgetTester tester) => TickerMode.valuesOf(tester.element(find.byType(MiniPlayer))).enabled;

  testWidgets('the mini player animates while shown, and stops when the keyboard or the player hides it',
      (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => _StillAudio()),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: MainNavigationScreen(child: SizedBox.expand())),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(miniPlayerTicks(tester), isTrue);

      // The keyboard comes up: the dock slides away and goes still.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pump(const Duration(milliseconds: 400));
      expect(miniPlayerTicks(tester), isFalse);

      tester.view.resetViewInsets();
      await tester.pump(const Duration(milliseconds: 400));
      expect(miniPlayerTicks(tester), isTrue);

      // The expanded player covers it.
      NavigationEvents.isPlayerExpanded.value = true;
      await tester.pump(const Duration(milliseconds: 400));
      expect(miniPlayerTicks(tester), isFalse);
      NavigationEvents.isPlayerExpanded.value = false;

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _noNetwork);
  });

  testWidgets('E-02: the bar teaches its gestures once, on the third tab change', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => _StillAudio()),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: MainNavigationScreen(child: SizedBox.expand())),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      final hint = find.textContaining('toca dos veces');
      // Two changes: nothing yet.
      for (final tab in ['BUSCAR', 'BIBLIOTECA']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(hint, findsNothing);
      await tester.tap(find.text('INICIO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(hint, findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('nav_gestures_hint_shown'), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    }, () => _noNetwork);
  });
}
