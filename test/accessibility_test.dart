import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/core/constants/app_colors.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/cover_colors.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/error_state.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/mini_player.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/playback_source_badge.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/track_tile.dart';

import 'helpers/test_scope.dart';

// U6: the widgets seen most follow Android's accessibility rules: every
// tappable thing is at least 48 px and has a name TalkBack reads, and text
// stands out from its background.

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

Future<void> _meetsAll(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// google_fonts asks the network for its fonts; nothing answers in a test.
final _noNetwork = MockClient((_) => Completer<http.Response>().future);
Future<void> _offline(Future<void> Function() body) => http.runWithClient(body, () => _noNetwork);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'];
        messenger.setMockMethodCallHandler(MethodChannel('com.ryanheise.just_audio.methods.$id'), (_) async => {});
      }
      return {};
    });
  });

  Widget app(Widget child, {List<Object> overrides = const []}) => TestScope(
    overrides: [
      playerTintColorProvider.overrideWithValue(const Color(0xFF8B5CF6)),
      playerBackgroundColorProvider.overrideWithValue(null),
      playbackSourceProvider.overrideWithValue(PlaybackSource.fullSong),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(backgroundColor: AppColors.bgDeep, body: child),
    ),
  );

  testWidgets(
    'a song row with its Oni mask to mark it',
    (tester) => _offline(() async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const Column(children: [TrackTile(track: _song, index: 1, showListenedCheckbox: true)])),
      );
      await _meetsAll(tester);
      expect(find.bySemanticsLabel('Marcar como escuchada'), findsOneWidget);
      handle.dispose();
    }),
  );

  testWidgets(
    'the mini player',
    (tester) => _offline(() async {
      final handle = tester.ensureSemantics();
      final audio = _StillAudio();
      await tester.pumpWidget(
        app(
          const Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
          overrides: [audioProvider.overrideWith((ref) => audio, disposeNotifier: false)],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _meetsAll(tester);
      await tester.pumpWidget(const SizedBox());
      audio.dispose();
      handle.dispose();
    }),
  );

  testWidgets(
    'the player badge and the error state',
    (tester) => _offline(() async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlaybackSourceBadge(),
              ErrorState(message: 'No se pudo cargar', onRetry: () {}),
            ],
          ),
        ),
      );
      await _meetsAll(tester);
      handle.dispose();
    }),
  );
}
