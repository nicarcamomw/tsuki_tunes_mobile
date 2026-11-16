import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/data/repositories/library_repository_impl.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/screens/main_navigation_screen.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/tsuki_nav_bar.dart';

import 'helpers/test_scope.dart';

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

/// A song playing (or none), with a queue of two.
class _Audio extends AudioProvider {
  _Audio({this.playing = true});
  final bool playing;
  int nexts = 0;

  @override
  Track? get currentTrack => playing ? _song : null;
  @override
  List<Track> get queue => playing ? const [_song, _song] : const [];
  @override
  Future<void> next() async => nexts++;
}

/// A library whose count of songs heard the test sets.
class _Library extends LibraryRepositoryImpl {
  int count = 0;
  @override
  int get listenedCount => count;
  void heard(int n) {
    count += n;
    notifyListeners();
  }
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  late _Library library;
  late Map<String, int> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
    library = _Library();
    calls = {};
    void count(String name) => calls[name] = (calls[name] ?? 0) + 1;
    NavigationEvents.onHomeScrollToTop = () => count('homeTop');
    NavigationEvents.onHomeRefresh = () => count('homeRefresh');
    NavigationEvents.onHomeOpenProfile = () => count('profile');
    NavigationEvents.onSearchFocus = () => count('searchFocus');
    NavigationEvents.onSearchClear = () => count('searchClear');
    NavigationEvents.onExploreScrollToTop = () => count('exploreTop');
    NavigationEvents.onLibraryScrollToTop = () => count('libraryTop');
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

  Future<void> run(WidgetTester tester, Future<void> Function() body, {_Audio? audio}) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => library),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => audio ?? _Audio()),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
        ],
        child: const MaterialApp(home: MainNavigationScreen(child: SizedBox.expand())),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 8));
    }, () => _noNetwork);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  const labels = ['INICIO', 'BUSCAR', 'EXPLORAR', 'BIBLIOTECA'];

  testWidgets('every tab\'s name sits on one line, whichever is active: nothing jumps', (tester) async {
    await run(tester, () async {
      for (final active in labels) {
        await tester.tap(find.text(active));
        await settle(tester);
        final ys = [for (final l in labels) tester.getCenter(find.text(l)).dy];
        final spread = ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThan(1), reason: 'with $active open');
      }
    });
  });

  testWidgets('the active name is in the red made for text; the others are muted', (tester) async {
    await run(tester, () async {
      Color colorOf(String label) {
        final style = tester.widget<AnimatedDefaultTextStyle>(
            find.ancestor(of: find.text(label), matching: find.byType(AnimatedDefaultTextStyle)).first);
        return style.style.color!;
      }

      expect(colorOf('INICIO'), AppColors.accentText);
      expect(colorOf('BUSCAR'), AppColors.textMuted);
    });
  });

  testWidgets('the lens slides to the open tab, stretching on its way', (tester) async {
    await run(tester, () async {
      final lens = find.byKey(TsukiNavBar.lensKey);
      final rest = tester.getSize(lens).width;
      expect(tester.getCenter(lens).dx, closeTo(tester.getCenter(find.text('INICIO')).dx, 1));

      await tester.tap(find.text('BIBLIOTECA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getSize(lens).width, greaterThan(rest * 1.5), reason: 'a drop between two tabs');

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(lens).width, closeTo(rest, 0.5));
      expect(tester.getCenter(lens).dx, closeTo(tester.getCenter(find.text('BIBLIOTECA')).dx, 1));
    });
  });

  testWidgets('Library counts the songs marked elsewhere, and TalkBack says so; opening it clears them', (tester) async {
    final handle = tester.ensureSemantics();
    await run(tester, () async {
      expect(find.text('+2'), findsNothing);
      library.heard(2);
      await settle(tester);
      expect(find.text('+2'), findsOneWidget);
      expect(find.bySemanticsLabel('BIBLIOTECA, pestaña 4 de 4, 2 canciones nuevas'), findsOneWidget);

      library.heard(9);
      await settle(tester);
      expect(find.text('9+'), findsOneWidget);

      await tester.tap(find.text('BIBLIOTECA'));
      await settle(tester);
      expect(find.text('9+'), findsNothing);
      expect(find.bySemanticsLabel('BIBLIOTECA, pestaña 4 de 4'), findsOneWidget);
    });
    handle.dispose();
  });

  testWidgets('TalkBack hears a tab bar: each tab its place, the open one selected', (tester) async {
    final handle = tester.ensureSemantics();
    await run(tester, () async {
      final home = tester.getSemantics(find.bySemanticsLabel('INICIO, pestaña 1 de 4'));
      expect(home.getSemanticsData().role, SemanticsRole.tab);
      expect(home.getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      final search = tester.getSemantics(find.bySemanticsLabel('BUSCAR, pestaña 2 de 4'));
      expect(search.getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
      expect(search.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
    });
    handle.dispose();
  });

  testWidgets('a new tab tapped twice quickly opens, then its tap-again shortcut; no double tap', (tester) async {
    await run(tester, () async {
      await tester.tap(find.text('BUSCAR'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('BUSCAR'));
      await settle(tester);
      expect(calls['searchClear'], isNull, reason: 'the double tap is for a tab already open');
      expect(calls['searchFocus'], 1);

      // Open now: a double tap clears the search.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('BUSCAR'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('BUSCAR'));
      await settle(tester);
      expect(calls['searchClear'], 1);
    });
  });

  testWidgets('holding a tab shows its shortcuts above it; choosing opens the tab and runs it', (tester) async {
    await run(tester, () async {
      await tester.longPress(find.text('BUSCAR'));
      await settle(tester);
      expect(find.text('Nueva búsqueda'), findsOneWidget);
      expect(find.text('Escribir en el buscador'), findsOneWidget);
      // Above the bar.
      expect(tester.getBottomLeft(find.text('Nueva búsqueda')).dy, lessThan(tester.getTopLeft(find.text('BUSCAR')).dy));

      await tester.tap(find.text('Nueva búsqueda'));
      await settle(tester);
      expect(calls['searchClear'], 1);
      final lens = find.byKey(TsukiNavBar.lensKey);
      expect(tester.getCenter(lens).dx, closeTo(tester.getCenter(find.text('BUSCAR')).dx, 1));

      // Home's: the profile, the top, a refresh. Dismissed, nothing runs.
      await tester.longPress(find.text('INICIO'));
      await settle(tester);
      expect(find.text('Ver perfil y ajustes'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      await tester.tapAt(const Offset(200, 100));
      await settle(tester);
      expect(calls['profile'], isNull);
    });
  });

  testWidgets('one dock: the song playing and the tabs share a single glass', (tester) async {
    await run(tester, () async {
      final dock = find.byKey(MainNavigationScreen.dockKey);
      expect(find.descendant(of: dock, matching: find.byType(MiniPlayer)), findsOneWidget);
      expect(find.descendant(of: dock, matching: find.byType(TsukiNavBar)), findsOneWidget);
    });
  });

  testWidgets('with nothing playing the dock is just the tabs', (tester) async {
    await run(tester, audio: _Audio(playing: false), () async {
      expect(find.text('Get Lucky'), findsNothing);
      expect(find.byType(TsukiNavBar), findsOneWidget);
    });
  });

  testWidgets('the mini player: a swipe shows the song it goes to; TalkBack has next, previous and open', (tester) async {
    final audio = _Audio();
    final handle = tester.ensureSemantics();
    await run(tester, audio: audio, () async {
      final row = find.text('Get Lucky');
      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await settle(tester);
      expect(audio.nexts, 1);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Get Lucky, Daft Punk')));
      final actions = node.getSemanticsData().customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .whereType<String>()
          .toSet();
      expect(actions, containsAll(['Abrir el reproductor', 'Siguiente pista', 'Pista anterior']));
    });
    handle.dispose();
  });

  testWidgets('the mini player lifts with a finger swiping up, and settles back if it lets go early', (tester) async {
    await run(tester, () async {
      final row = find.text('Get Lucky');
      final rest = tester.getCenter(row).dy;
      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      expect(tester.getCenter(row).dy, lessThan(rest - 8), reason: 'half the finger\'s way, short of opening');
      await gesture.up();
      await tester.pump();
      expect(tester.getCenter(row).dy, closeTo(rest, 0.5));
      expect(NavigationEvents.isPlayerExpanded.value, isFalse);
    });
  });
}
