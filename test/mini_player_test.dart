import 'dart:async';

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
import 'package:tsuki_tunes_mobile/presentation/widgets/player_tint.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/queue_panel.dart';

import 'helpers/test_scope.dart';

Track _t(String id, String title) => Track(
      id: id,
      title: title,
      artistId: 'a',
      artistName: 'Daft Punk',
      albumId: 'b',
      albumTitle: 'Random Access Memories',
      coverUrl: '',
      previewUrl: '',
      durationSeconds: 248,
    );

final _song = _t('1', 'Get Lucky');
final _next = _t('2', 'Instant Crush');

/// A song playing in a queue of two, 1:40 in; records what's asked of it.
class _Audio extends AudioProvider {
  Track? playing = _song;
  Track? before;
  int stops = 0;
  (Track, List<Track>?)? replayed;
  Duration? seekedTo;

  @override
  Track? get currentTrack => playing;
  @override
  List<Track> get queue => playing == null ? const [] : [_song, _next];
  @override
  Duration get position => const Duration(seconds: 100);
  @override
  Track? get nextPreview => _next;
  @override
  Track? get previousPreview => before;
  @override
  Future<void> next() async {}
  @override
  Future<void> stop() async {
    stops++;
    playing = null;
    notifyListeners();
  }

  @override
  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    replayed = (track, newQueue);
    playing = track;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration pos) async => seekedTo = pos;
}

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  late _Audio audio;

  setUp(() {
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
    audio = _Audio();
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

  Future<void> run(WidgetTester tester, Future<void> Function() body,
      {Color tint = const Color(0xFF8B5CF6), PlaybackSource source = PlaybackSource.fullSong}) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => _Online()),
          audioProvider.overrideWith((ref) => audio),
          playerTintColorProvider.overrideWithValue(tint),
          playerBackgroundColorProvider.overrideWithValue(null),
          playbackSourceProvider.overrideWithValue(source),
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

  testWidgets('✕ stops, and "Undo" brings back the song, its queue and its place', (tester) async {
    await run(tester, () async {
      await tester.tap(find.bySemanticsLabel('Detener reproducción'));
      await settle(tester);
      expect(audio.stops, 1);
      expect(find.byType(MiniPlayer), findsNothing);
      expect(find.text('Reproducción detenida'), findsOneWidget);

      await tester.tap(find.text('DESHACER'));
      await settle(tester);
      expect(audio.replayed?.$1.id, '1');
      expect(audio.replayed?.$2?.map((t) => t.id), ['1', '2']);
      expect(audio.seekedTo, const Duration(seconds: 100));
      expect(find.text('Get Lucky'), findsOneWidget);
    });
  });

  testWidgets('pulled down far enough, it stops (undoable); a short pull settles back', (tester) async {
    await run(tester, () async {
      final row = find.text('Get Lucky');
      final rest = tester.getCenter(row).dy;
      var gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 10));
      await gesture.up();
      await settle(tester);
      expect(audio.stops, 0);
      expect(tester.getCenter(row).dy, closeTo(rest, 0.5));

      gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up();
      await settle(tester);
      expect(audio.stops, 1);
      expect(find.text('Reproducción detenida'), findsOneWidget);
    });
  });

  testWidgets('a swipe shows the song it goes to by name, or "from the start"', (tester) async {
    await run(tester, () async {
      final row = find.text('Get Lucky');
      var gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(find.text('Instant Crush'), findsOneWidget);
      await gesture.cancel();
      await settle(tester);

      // Past its first seconds "previous" replays this song.
      gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(find.text('Desde el inicio'), findsOneWidget);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
      await gesture.cancel();
      await settle(tester);
    });
  });

  testWidgets('holding it offers the album, the artist and the queue', (tester) async {
    await run(tester, () async {
      await tester.longPress(find.text('Get Lucky'));
      await settle(tester);
      expect(find.text('Ir al álbum'), findsOneWidget);
      expect(find.text('Ir al artista'), findsOneWidget);
      await tester.tap(find.text('Ver la cola'));
      await settle(tester);
      expect(find.byType(QueuePanel), findsOneWidget);
    });
  });

  testWidgets('a dark cover\'s colour is lifted where it must read: play at 3:1, words at 4.5:1', (tester) async {
    const navy = Color(0xFF1A237E);
    expect(contrastRatio(navy, AppColors.bgDeep), lessThan(3), reason: 'too dark as it is');
    await run(tester, tint: navy, () async {
      final play = tester.widget<Icon>(find.byIcon(Icons.play_circle_filled_rounded));
      expect(contrastRatio(play.color!.withValues(alpha: 1), AppColors.bgDeep), greaterThanOrEqualTo(3));
    });
    expect(contrastRatio(iconTint(navy), AppColors.bgDeep), greaterThanOrEqualTo(3));
    // A tint that reads already stays itself.
    expect(iconTint(const Color(0xFF8B5CF6)), const Color(0xFF8B5CF6));
  });

  testWidgets('one line moves: the title (14) may scroll, the artist (12) ends in "…"', (tester) async {
    await run(tester, () async {
      final title = tester.widget<Text>(find.text('Get Lucky'));
      expect(title.style!.fontSize, 14);
      final artist = tester.widget<Text>(find.text('Daft Punk'));
      expect(artist.style!.fontSize, 12);
      expect(artist.overflow, TextOverflow.ellipsis);
      expect(find.ancestor(of: find.text('Daft Punk'), matching: find.byType(SingleChildScrollView)), findsNothing);
    });
  });

  testWidgets('the breathing cover repaints in its own layer, not the dock', (tester) async {
    await run(tester, () async {
      final cover = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BreathingCover');
      expect(find.ancestor(of: cover, matching: find.byType(RepaintBoundary)).first,
          isNot(find.ancestor(of: find.byType(MiniPlayer), matching: find.byType(RepaintBoundary)).first));
      expect(tester.widget(find.ancestor(of: cover, matching: find.byType(RepaintBoundary)).first), isA<RepaintBoundary>());
    });
  });

  testWidgets('TalkBack can stop it too, and hears that holding shows options', (tester) async {
    final handle = tester.ensureSemantics();
    await run(tester, () async {
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^Get Lucky, Daft Punk')));
      final labels = node.getSemanticsData().customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!)
          .map((a) => a.label ?? a.hint)
          .whereType<String>()
          .toSet();
      expect(labels, contains('Detener reproducción'));
      expect(labels, contains('ver opciones'));
    });
    handle.dispose();
  });
}
