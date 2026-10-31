import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/providers/app_providers.dart';
import 'package:tsuki_tunes_mobile/providers/audio_provider.dart';
import 'package:tsuki_tunes_mobile/providers/library_provider.dart';
import 'package:tsuki_tunes_mobile/screens/guess_song_screen.dart';
import 'package:tsuki_tunes_mobile/services/guess_game.dart';
import 'helpers/test_scope.dart';

/// Clips load and "play" without a real audio backend.
class _FakeAudio extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => _FakePlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async =>
      DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

class _FakePlayer extends AudioPlayerPlatform {
  _FakePlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _events.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updateTime: DateTime.now(),
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: const Duration(seconds: 30),
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }
}

const _artistId = '27';

Map<String, dynamic> _track(String id, String title,
        {String artistId = _artistId, String artist = 'Bad Bunny', int rank = 500000}) =>
    {
      'id': int.parse(id),
      'title': title,
      'duration': 200,
      'rank': rank,
      'preview': 'https://cdn.example/$id.mp3',
      'artist': {'id': int.parse(artistId), 'name': artist},
      'album': {'id': 1, 'title': 'Album', 'cover_medium': ''},
    };

// Ten top songs; "Un Coco" is not among them and is not popular enough to
// pass the general search's rank filter.
final _top = [for (var i = 1; i <= 10; i++) _track('${100 + i}', 'Hit $i')];
final _unCoco = _track('900', 'UN COCO', rank: 4000);
final _otherCoco = _track('901', 'Un Coco', artistId: '5', artist: 'Otra Banda');

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

final _client = MockClient((req) async {
  // Fonts never arrive (the default font is used); only Deezer answers.
  if (req.url.host != 'api.deezer.com') return Completer<http.Response>().future;
  final path = req.url.path;
  if (path == '/artist/$_artistId/top') return _json({'data': _top});
  if (path == '/search/track') {
    final q = req.url.queryParameters['q']!.toLowerCase();
    return _json({'data': q.contains('coco') ? [_unCoco, _otherCoco] : []});
  }
  if (path.startsWith('/track/')) {
    final id = path.split('/').last;
    return _json([..._top, _unCoco, _otherCoco].firstWhere((t) => '${t['id']}' == id));
  }
  return http.Response('{"data":[]}', 200);
});

void main() {
  setUpAll(() {
    JustAudioPlatform.instance = _FakeAudio();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'guess_last_mode': 'artist',
      'guess_last_artist': jsonEncode({'id': _artistId, 'name': 'Bad Bunny', 'picture_medium': ''}),
    });
  });

  Widget app({Key? key}) => TestScope(
        overrides: [
          audioProvider.overrideWith((ref) => AudioProvider()),
          libraryProvider.overrideWith((ref) => LibraryProvider()),
        ],
        child: MaterialApp(home: GuessSongScreen(key: key)));

  // The API's disk cache does real file I/O, which only completes outside
  // the fake clock; alternate real waits with frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  // Close the screen and let its pending timers run out.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('artist mode finds songs outside the top tracks, only by that artist',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'un coco');
      await settle(tester);

      expect(find.text('UN COCO'), findsOneWidget);
      expect(find.text('Otra Banda'), findsNothing);
      expect(tester.takeException(), isNull);
      await leave(tester);
    }, () => _client);
  });

  testWidgets('leaving mid-round and coming back keeps the round', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(app(key: const ValueKey(1)));
      await settle(tester);

      await tester.tap(find.text('SALTAR (+1s)'));
      await settle(tester);
      expect(find.text('Saltado'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final saved = DailyRoundState.decode(prefs.getString('guess_round_artist'))!;
      expect(saved.outcomes, [GuessOutcome.skipped]);
      expect(saved.scope, _artistId);

      // Leave the screen, then open it again.
      await leave(tester);
      await tester.pumpWidget(app(key: const ValueKey(2)));
      await settle(tester);

      expect(find.text('Artista', skipOffstage: false), findsOneWidget);
      expect(find.text('Saltado'), findsOneWidget);
      expect(find.text('SALTAR (+2s)'), findsOneWidget);
      final again = DailyRoundState.decode(prefs.getString('guess_round_artist'))!;
      expect(again.trackId, saved.trackId);
      expect(tester.takeException(), isNull);
      await leave(tester);
    }, () => _client);
  });
}
