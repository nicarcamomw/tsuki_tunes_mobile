import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/expanded_player_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/main_navigation_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/test_scope.dart';

// 120 fps leaves ~8 ms a frame. Work the app does on the UI thread each
// frame (widgets rebuilt) is what eats it: these keep the common moments
// to the widgets that actually change.

final _songs = [
  for (var i = 0; i < 12; i++)
    Track(
      id: '$i',
      title: 'Song $i',
      artistId: 'a',
      artistName: 'Daft Punk',
      albumId: 'b',
      albumTitle: 'Discovery',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 240,
    ),
];

/// A song playing whose position the test moves, as the player would.
class _Playing extends AudioProvider {
  final ValueNotifier<int> ticks = ValueNotifier(0);
  Duration at = const Duration(seconds: 30);
  Track playing = _songs.first;
  bool paused = false;

  void moveToNext() {
    playing = _songs[(_songs.indexOf(playing) + 1) % _songs.length];
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    notifyListeners();
  }

  @override
  Track? get currentTrack => playing;
  @override
  bool get isPlaying => !paused;
  @override
  Duration get position => at;
  @override
  Duration get duration => const Duration(seconds: 240);
  @override
  List<Track> get queue => _songs;
  @override
  Listenable get progressListenable => ticks;

  void advance() {
    at += const Duration(milliseconds: 200);
    ticks.value++;
  }
}

/// A library that can be told something changed (a sync landing) without
/// anything the screen shows changing.
class _Library extends LibraryRepositoryImpl {
  void ping() => notifyListeners();
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Counts the widgets rebuilt while [body] runs, by type.
Future<Map<String, int>> countRebuilds(Future<void> Function() body) async {
  final counts = <String, int>{};
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final name = element.widget.runtimeType.toString();
    counts[name] = (counts[name] ?? 0) + 1;
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
  return counts;
}

/// The player's colour, changeable as a song with another cover starts.
class _Tint extends Notifier<Color> {
  @override
  Color build() => const Color(0xFF8B5CF6);
  void set(Color c) => state = c;
}

final _tint = NotifierProvider<_Tint, Color>(_Tint.new);

int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

String top(Map<String, int> m) {
  final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return e.take(int.tryParse(const String.fromEnvironment('TOP', defaultValue: '12')) ?? 12).map((e) => '${e.key}×${e.value}').join(', ');
}

void main() {
  late _Playing audio;
  late _Library library;

  setUp(() {
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
    audio = _Playing();
    library = _Library();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
  });

  Future<void> run(WidgetTester tester, Widget page, Future<void> Function() body) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => library),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => audio),
          playerTintColorProvider.overrideWith((ref) => ref.watch(_tint)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: MaterialApp(home: MainNavigationScreen(child: page)),
      ));
      // Settle: the first breaths and glides done.
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  }

  final list = Material(
    child: ListView(children: [for (var i = 0; i < _songs.length; i++) TrackTile(track: _songs[i], index: i, queue: _songs)]),
  );

  testWidgets('the song moving on: only its progress is rebuilt', (tester) async {
    await run(tester, list, () async {
      final counts = await countRebuilds(() async {
        for (var i = 0; i < 10; i++) {
          audio.advance();
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
      debugPrint('PROGRESS ${total(counts)}: ${top(counts)}');
      expect(total(counts), lessThanOrEqualTo(10 * 3), reason: top(counts));
    });
  });

  testWidgets('the keyboard sliding up: the shell is rebuilt once (as it opens), not on every frame', (tester) async {
    await run(tester, list, () async {
      final frames = <Map<String, int>>[];
      for (var i = 1; i <= 10; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: 60.0 * i);
        frames.add(await countRebuilds(() => tester.pump(const Duration(milliseconds: 16))));
      }
      tester.view.resetViewInsets();
      await tester.pump(const Duration(milliseconds: 16));
      // The first frame: the keyboard has opened, the dock goes. After it,
      // only the page's insets follow the keyboard.
      for (final frame in frames.skip(1)) {
        for (final heavy in ['TrackTile', 'TapScale', 'OniMaskIcon', 'CyberNavIcon', 'MiniPlayer', 'TsukiNavBar']) {
          expect(frame[heavy] ?? 0, 0, reason: '$heavy rebuilt as the keyboard slid: ${top(frame)}');
        }
        expect(total(frame), lessThan(60), reason: top(frame));
      }
    });
  });

  testWidgets('a library sync that changes nothing shown: next to nothing is rebuilt', (tester) async {
    await run(tester, list, () async {
      final counts = await countRebuilds(() async {
        for (var i = 0; i < 5; i++) {
          library.ping();
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      debugPrint('SYNC ${total(counts)}: ${top(counts)}');
      expect(total(counts), lessThan(5 * 6), reason: top(counts));
    });
  });

  testWidgets('changing tabs: the bar and the shell, not the pages', (tester) async {
    await run(tester, const MainTabsView(), () async {
      final counts = await countRebuilds(() async {
        debugPrintScheduleBuildForStacks = const bool.fromEnvironment('TRACE');
        await tester.tap(find.text('EXPLORAR'));
        await tester.pump();
        debugPrintScheduleBuildForStacks = false;
      });
      debugPrint('TAB ${total(counts)}: ${top(counts)}');
      // The bar and the tabs' stack change; the shell around them, the
      // song playing and Home don't.
      for (final untouched in ['MainNavigationScreen', 'MiniPlayer', 'HomeScreen']) {
        expect(counts[untouched] ?? 0, 0, reason: '$untouched rebuilt on a tab change: ${top(counts)}');
      }
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('pause, play, next song: only the rows whose state changes are rebuilt', (tester) async {
    await run(tester, list, () async {
      final counts = await countRebuilds(() async {
        audio.togglePause();
        await tester.pump(const Duration(milliseconds: 16));
        audio.togglePause();
        await tester.pump(const Duration(milliseconds: 16));
        audio.moveToNext();
        await tester.pump(const Duration(milliseconds: 16));
      });
      debugPrint('ROWS ${counts['TrackTile']}: ${top(counts)}');
      // Pause and play touch the playing row; the next song, the two that
      // swap. Not every row on screen each time.
      expect(counts['TrackTile'] ?? 0, lessThanOrEqualTo(4), reason: top(counts));
    });
  });

  testWidgets('dragging the player down to close it: it moves, nothing in it is rebuilt', (tester) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => library),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => audio),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: ExpandedPlayerScreen()),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      // What the player redraws on its own (the disc turning), to tell
      // apart from what the drag adds.
      final idle = await countRebuilds(() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      final gesture = await tester.startGesture(const Offset(200, 60));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
      final pulling = await countRebuilds(() async {
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, 8));
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      // Let go short of closing: it springs back.
      final springing = await countRebuilds(() async {
        await gesture.up();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      final perFrame = total(idle) / 6;
      debugPrint('IDLE ${total(idle)}: ${top(idle)}');
      debugPrint('PULL ${total(pulling)}: ${top(pulling)}');
      debugPrint('SPRING ${total(springing)}: ${top(springing)}');
      // Only the offset follows the finger: one widget a frame on top of
      // what it already redraws, not the cover, the controls and the lyrics.
      expect(total(pulling) - 6 * perFrame, lessThanOrEqualTo(6 * 1), reason: top(pulling));
      expect(total(springing) - 20 * perFrame, lessThanOrEqualTo(20 * 1), reason: top(springing));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  });

  testWidgets('swiping or lifting the mini player: it moves, its cover, title and buttons aren\'t rebuilt', (tester) async {
    await run(tester, list, () async {
      final mini = tester.getCenter(find.byType(MiniPlayer));
      Future<Map<String, int>> drag(Offset step) async {
        final gesture = await tester.startGesture(mini);
        await gesture.moveBy(step * 3);
        await tester.pump(const Duration(milliseconds: 16));
        final counts = await countRebuilds(() async {
          for (var i = 0; i < 6; i++) {
            await gesture.moveBy(step);
            await tester.pump(const Duration(milliseconds: 16));
          }
        });
        // Slowly back where it started, and let go: nothing happens; it
        // settles before the next drag.
        for (var i = 0; i < 9; i++) {
          await gesture.moveBy(-step);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.up();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        return counts;
      }

      final sideways = await drag(const Offset(-6, 0));
      final up = await drag(const Offset(0, -4));
      debugPrint('SWIPE ${total(sideways)}: ${top(sideways)}');
      debugPrint('LIFT ${total(up)}: ${top(up)}');
      for (final counts in [sideways, up]) {
        for (final heavy in ['MiniPlayer', 'TapScale', 'CachedNetworkImage', 'OniMaskIcon', 'AnimatedSwitcher']) {
          expect(counts[heavy] ?? 0, 0, reason: '$heavy rebuilt as the row moved: ${top(counts)}');
        }
      }
      // Sideways, only the hint of the song it goes to follows the finger;
      // lifting, only the row's offset.
      expect(total(sideways), lessThanOrEqualTo(6 * 6), reason: top(sideways));
      expect(total(up), lessThanOrEqualTo(6 * 1), reason: top(up));
    });
  });

  testWidgets('the colour fading to the new cover\'s: the mini player is rebuilt once, only the tinted bits follow the fade', (tester) async {
    await run(tester, list, () async {
      final container = ProviderScope.containerOf(tester.element(find.byType(MiniPlayer)));
      final counts = await countRebuilds(() async {
        container.read(_tint.notifier).set(const Color(0xFF3B82F6));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      debugPrint('TINT ${total(counts)}: ${top(counts)}');
      // The bar, the row's buttons, texts and cover: at most once (as the
      // colour changes), not on each of the fade's ~30 frames. Only what's
      // painted in the colour follows it.
      for (final (heavy, instances) in [
        ('TsukiNavBar', 1),
        ('_NavItem', 4),
        ('TapScale', 7),
        ('Tooltip', 1),
        ('OniMaskIcon', 1),
        ('_MarqueeText', 1),
        ('_BreathingCover', 1),
        ('PlayerArtHero', 1),
      ]) {
        expect(counts[heavy] ?? 0, lessThanOrEqualTo(instances), reason: '$heavy rebuilt through the fade: ${top(counts)}');
      }
      expect(total(counts), lessThan(40 * 20), reason: top(counts));
    });
  });

  testWidgets('the colour fading to the new cover\'s in the open player: only what\'s painted in it follows', (tester) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => library),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => audio),
          playerTintColorProvider.overrideWith((ref) => ref.watch(_tint)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: ExpandedPlayerScreen()),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final container = ProviderScope.containerOf(tester.element(find.byType(ExpandedPlayerScreen)));
      final counts = await countRebuilds(() async {
        container.read(_tint.notifier).set(const Color(0xFF3B82F6));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      debugPrint('PLAYER TINT ${total(counts)}: ${top(counts)}');
      // The screen's layout (top bar, cover, title, controls, lyrics card):
      // at most once, as the colour changes; not on each frame of the fade.
      for (final heavy in ['Scaffold', 'LyricsCard', 'Spacer', 'SafeArea', 'InkWell', 'TapScale']) {
        expect(counts[heavy] ?? 0, lessThanOrEqualTo(8), reason: '$heavy rebuilt through the fade: ${top(counts)}');
      }
      expect(total(counts), lessThan(40 * 30), reason: top(counts));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    }, () => MockClient((_) async => http.Response('{"data":[]}', 200)));
  });
}
