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
import 'package:tsuki_tunes_mobile/presentation/state/mask_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/oni_mask_art.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/test_scope.dart';

// 120 fps: every frame the app draws re-renders the dock's glass (a blur).
// With music playing and nobody touching the phone, nothing may keep asking
// for frames: animations play when something happens, then rest.

const _song = Track(
  id: '1',
  title: 'Harder, Better, Faster, Stronger (Alive 2007 version, extended)',
  artistId: 'a',
  artistName: 'Daft Punk',
  albumId: 'b',
  albumTitle: 'Discovery',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 248,
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
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
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

  Future<void> run(WidgetTester tester, Widget page, Future<void> Function() body) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => _Playing()),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: MaterialApp(home: MainNavigationScreen(child: page)),
      ));
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    }, () => _noNetwork);
  }

  /// Lets [time] pass a frame at a time, as the phone would.
  Future<void> wait(WidgetTester tester, Duration time) async {
    final frames = time.inMilliseconds ~/ 250;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('music playing, a long title, nobody touching: the app goes still', (tester) async {
    await run(tester, const SizedBox.expand(), () async {
      await tester.pump();
      // Something moves at first: the cover breathes, the title glides.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      // Then rest.
      await wait(tester, const Duration(seconds: 16));
      expect(tester.hasRunningAnimations, isFalse, reason: 'a ticker still running would redraw the dock every frame');
    });
  });

  testWidgets('the song playing in a list: its bars dance, then rest', (tester) async {
    await run(tester, const Material(child: ListTileTheme(child: TrackTile(track: _song, index: 1))), () async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await wait(tester, const Duration(seconds: 16));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('a UL mask\'s light goes round, then rests', (tester) async {
    final masks = MaskProvider(clock: () => DateTime(2026, 11, 12, 15));
    await tester.runAsync(() => masks.ready);
    final ul = MaskCatalog.all.firstWhere((m) => m.rarity == MaskRarity.ul);
    await tester.pumpWidget(TestScope(child: MaterialApp(home: Center(child: OniMaskArt(mask: ul, size: 120, unlocked: true)))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'it turns');
    await wait(tester, const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse, reason: 'and rests');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    masks.dispose();
  });
}
