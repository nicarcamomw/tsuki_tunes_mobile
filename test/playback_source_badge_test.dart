import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/playback_source_badge.dart';

import 'helpers/test_scope.dart';

// U2: the player says whether the whole song plays or a 30 s preview,
// and why, in the app's language (Spanish here).

PlaybackSource _source({bool full = false, bool connected = true, SpotifyFallbackReason? fallback}) =>
    PlaybackSource.of(
      playsFullSong: full,
      spotifyConnected: connected,
      premium: true,
      notAllowed: false,
      online: true,
      fallback: fallback,
    );

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

/// A song loaded, nothing really playing.
class _StillAudio extends AudioProvider {
  @override
  Track? get currentTrack => _song;
}

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

  Widget badge(PlaybackSource source) => TestScope(
        overrides: [
          playbackSourceProvider.overrideWithValue(source),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
        ],
        child: const MaterialApp(home: Scaffold(body: Center(child: PlaybackSourceBadge()))),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(PlaybackSourceBadge));
    await tester.pumpAndSettle();
  }

  testWidgets('the whole song from Spotify', (tester) async {
    await tester.pumpWidget(badge(_source(full: true)));
    expect(find.text('CANCIÓN COMPLETA · SPOTIFY'), findsOneWidget);
    await openSheet(tester);
    expect(find.text('Suena la canción completa'), findsOneWidget);
    expect(find.text('CONECTAR'), findsNothing);
  });

  testWidgets('a preview without Spotify offers to connect it', (tester) async {
    await tester.pumpWidget(badge(_source(connected: false)));
    expect(find.text('VISTA PREVIA · 30 S'), findsOneWidget);
    await openSheet(tester);
    expect(find.text('Suena una vista previa de 30 segundos'), findsOneWidget);
    expect(find.textContaining('Conecta tu Spotify Premium'), findsOneWidget);
    expect(find.text('CONECTAR'), findsOneWidget);
  });

  testWidgets('a preview with Spotify connected says Spotify\'s reason, not "Spotify"', (tester) async {
    await tester.pumpWidget(badge(_source(fallback: SpotifyFallbackReason.trackUnavailable)));
    expect(find.text('VISTA PREVIA · 30 S'), findsOneWidget);
    expect(find.text('CANCIÓN COMPLETA · SPOTIFY'), findsNothing);
    await openSheet(tester);
    expect(find.textContaining('no está en Spotify'), findsOneWidget);
    expect(find.text('CONECTAR'), findsNothing);
  });

  testWidgets('the mini player says "30 S" after the artist only for a preview', (tester) async {
    for (final full in [false, true]) {
      final audio = _StillAudio();
      await tester.pumpWidget(TestScope(
        overrides: [
          audioProvider.overrideWith((ref) => audio, disposeNotifier: false),
          playbackSourceProvider.overrideWithValue(_source(full: full)),
          playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
          playerBackgroundColorProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer()))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('30 S', findRichText: true).evaluate().isNotEmpty, !full, reason: 'full: $full');
      await tester.pumpWidget(const SizedBox());
      audio.dispose();
    }
  });
}
