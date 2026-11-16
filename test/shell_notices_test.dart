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

/// A song playing; the test sets its errors, its loading and whether a
/// next song waits, and counts what the notices ask of it.
class _Audio extends AudioProvider {
  PlaybackError? error;
  SpotifyFallbackReason? spotifyError;
  bool loading = false;
  bool nextWaits = true;
  int nexts = 0;
  Track? replayed;

  @override
  Track? get currentTrack => _song;
  @override
  PlaybackError? get lastPlaybackError => error;
  @override
  SpotifyFallbackReason? get lastSpotifyError => spotifyError;
  @override
  bool get isBuffering => loading;
  @override
  Track? get nextPreview => nextWaits ? _song : null;
  @override
  Future<void> next() async => nexts++;
  @override
  Future<void> playTrack(Track track, {List<Track>? newQueue}) async => replayed = track;

  void set({PlaybackError? error, bool? loading}) {
    this.error = error;
    if (loading != null) this.loading = loading;
    notifyListeners();
  }

  void spotifyFails(SpotifyFallbackReason? reason) {
    spotifyError = reason;
    notifyListeners();
  }

  void poke() => notifyListeners();
}

/// A library whose last refused change the test sets.
class _Library extends LibraryRepositoryImpl {
  String? refused;
  @override
  String? get lastSyncError => refused;
  void refuse(String? what) {
    refused = what;
    notifyListeners();
  }
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
  late _Library library;

  setUp(() {
    SharedPreferences.setMockInitialValues({'nav_gestures_hint_shown': true});
    audio = _Audio();
    connection = _Connection();
    library = _Library();
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
          libraryProvider.overrideWith((ref) => library),
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

  /// Lets a notice go: its way in, its time, its way out.
  Future<void> letGo(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Causes a notice and lets it come in (the frame it's shown, then its
  /// entrance).
  Future<void> show(WidgetTester tester, void Function() cause) async {
    cause();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('no preview: "Next" plays the next song; with none waiting, no button', (tester) async {
    await run(tester, () async {
      await show(tester, () => audio.set(error: PlaybackError.noPreview));
      expect(find.text('Esta canción no tiene vista previa'), findsOneWidget);
      await tester.tap(find.text('SIGUIENTE'));
      await tester.pump();
      expect(audio.nexts, 1);
      await letGo(tester);

      audio.nextWaits = false;
      await show(tester, () => audio.set(error: null));
      await show(tester, () => audio.set(error: PlaybackError.noPreview));
      expect(find.text('Esta canción no tiene vista previa'), findsOneWidget);
      expect(find.text('SIGUIENTE'), findsNothing);
      await letGo(tester);
    });
  });

  testWidgets('a network error online: "Retry" tries the same song again; offline: "Next"', (tester) async {
    await run(tester, () async {
      await show(tester, () => audio.set(error: PlaybackError.network));
      expect(find.text('Falló la conexión al cargar la canción'), findsOneWidget);
      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();
      expect(audio.replayed?.id, _song.id);
      await letGo(tester);

      connection.set(false);
      await show(tester, () => audio.set(error: null));
      await show(tester, () => audio.set(error: PlaybackError.network));
      expect(find.text('Sin conexión: esta canción no está guardada'), findsOneWidget);
      expect(find.text('REINTENTAR'), findsNothing);
      expect(find.text('SIGUIENTE'), findsOneWidget);
      await letGo(tester);
    });
  });

  testWidgets('Spotify closed: "Open Spotify"; Spotify paused is told once a session', (tester) async {
    await run(tester, () async {
      await show(tester, () => audio.spotifyFails(SpotifyFallbackReason.openApp));
      expect(find.text('Abre Spotify para escuchar la canción completa'), findsOneWidget);
      expect(find.text('ABRIR SPOTIFY'), findsOneWidget);
      await letGo(tester);

      const paused = 'Spotify está en pausa un momento: suenan vistas previas';
      await show(tester, () => audio.spotifyFails(SpotifyFallbackReason.disabled));
      expect(find.text(paused), findsOneWidget);
      await letGo(tester);
      await show(tester, () => audio.spotifyFails(null));
      await show(tester, () => audio.spotifyFails(SpotifyFallbackReason.disabled));
      expect(find.text(paused), findsNothing, reason: 'the same news, already told');
    });
  });

  testWidgets('a change the server refused is said as what happened, not "try again"', (tester) async {
    await run(tester, () async {
      await show(tester, () => library.refuse('mark_failed'));
      expect(find.text('No se pudo marcar como escuchada: quedó como estaba'), findsOneWidget);
      await letGo(tester);
      await show(tester, () => library.refuse(null));
      await show(tester, () => library.refuse('unmark_failed'));
      expect(find.text('No se pudo desmarcar: sigue como escuchada'), findsOneWidget);
      expect(find.textContaining('Intenta de nuevo'), findsNothing);
      await letGo(tester);
    });
  });
}

