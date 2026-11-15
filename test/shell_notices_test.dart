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
import 'package:tsuki_tunes_mobile/presentation/widgets/connection_notice.dart';

import 'helpers/test_scope.dart';

// E-03 and the connection notice: what the shell tells, once, over its dock.

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

/// A song playing; the test sets its playback error and its loading.
class _Audio extends AudioProvider {
  PlaybackError? error;
  bool loading = false;

  @override
  Track? get currentTrack => _song;
  @override
  PlaybackError? get lastPlaybackError => error;
  @override
  bool get isBuffering => loading;
  void set({PlaybackError? error, bool? loading}) {
    this.error = error;
    if (loading != null) this.loading = loading;
    notifyListeners();
  }

  void poke() => notifyListeners();
}

class _Connection extends ChangeNotifier implements ConnectivityProvider {
  bool online = true;
  @override
  bool get isOnline => online;
  void set(bool value) {
    online = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _noNetwork = MockClient((_) => Completer<http.Response>().future);

void main() {
  late _Audio audio;
  late _Connection connection;

  setUp(() {
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
    audio = _Audio();
    connection = _Connection();
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

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    tester.view.physicalSize = const Size(400 * 2, 860 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(TestScope(
        overrides: [
          libraryProvider.overrideWith((ref) => LibraryRepositoryImpl()),
          connectivityProvider.overrideWith((ref) => connection),
          audioProvider.overrideWith((ref) => audio),
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

  Future<void> wait(WidgetTester tester, Duration d) async {
    await tester.pump();
    await tester.pump(d);
  }

  testWidgets('offline: a pill drops in; back online it says so for a moment, then leaves', (tester) async {
    final handle = tester.ensureSemantics();
    await run(tester, () async {
      final pill = find.byType(ConnectionNotice);
      double top() => tester.getTopLeft(find.descendant(of: pill, matching: find.byType(Row)).first).dy;
      final hidden = top();
      expect(hidden, lessThan(0), reason: 'above the screen while online');

      connection.set(false);
      await wait(tester, const Duration(milliseconds: 400));
      expect(find.text('Sin conexión a internet'), findsOneWidget);
      expect(top(), greaterThan(0));
      // TalkBack is told.
      final node = tester.getSemantics(find.bySemanticsLabel('Sin conexión a internet'));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);

      connection.set(true);
      await wait(tester, const Duration(milliseconds: 400));
      expect(find.text('De nuevo en línea'), findsOneWidget);
      expect(top(), greaterThan(0));

      await wait(tester, ConnectionNotice.backFor);
      await wait(tester, const Duration(milliseconds: 400));
      expect(top(), lessThan(0), reason: 'gone again');
    });
    handle.dispose();
  });

  testWidgets('E-03: a playback error shows once; rebuilds don\'t repeat it; a new one does', (tester) async {
    await run(tester, () async {
      audio.set(error: PlaybackError.noPreview);
      await wait(tester, const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.music_off_rounded), findsOneWidget);

      // Let it go; the shell rebuilds for other reasons: nothing again.
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byIcon(Icons.music_off_rounded), findsNothing);
      audio.poke();
      await tester.tap(find.text('BUSCAR'));
      await wait(tester, const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.music_off_rounded), findsNothing);

      // Cleared, then the same error again: told again.
      audio.set(error: null);
      await wait(tester, const Duration(milliseconds: 100));
      audio.set(error: PlaybackError.noPreview);
      await wait(tester, const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.music_off_rounded), findsOneWidget);
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  });

  testWidgets('the mini player: loading runs a ring around the play button, which stays seen', (tester) async {
    await run(tester, () async {
      expect(find.byType(CircularProgressIndicator), findsNothing);
      audio.set(loading: true);
      await wait(tester, const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsOneWidget);
      audio.set(loading: false);
      await wait(tester, const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
