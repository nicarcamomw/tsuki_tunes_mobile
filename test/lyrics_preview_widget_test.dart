import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/lyrics_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/app_providers.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/lyrics_view.dart';

const _track = Track(
  id: '1',
  title: 'Song',
  artistId: 'a',
  artistName: 'Artist',
  albumId: '',
  albumTitle: '',
  coverUrl: '',
  previewUrl: 'https://example.com/1.mp3',
  durationSeconds: 200,
);

class _Player extends AudioPlayerService {
  final seeks = <Duration>[];

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {}

  @override
  Future<void> seek(Duration position) async => seeks.add(position);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LyricsService().clearCache();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async {
      if (call.method == 'init') {
        final id = call.arguments['id'];
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'), (call) async => {});
      }
      return {};
    });
  });

  testWidgets('a preview shows synced lyrics unsynced, and a tap doesn\'t jump', (tester) async {
    final player = _Player();
    final audio = AudioProvider(service: player, storage: StorageService());
    final controller = LyricsController();
    final client = MockClient((req) async => req.url.path == '/api/get'
        ? http.Response.bytes(
            utf8.encode(jsonEncode({'syncedLyrics': '[00:05.00]First line\n[02:15.00]Late line'})), 200)
        : http.Response('[]', 200));

    await tester.runAsync(() => http.runWithClient(() async {
          controller.ensureFor(_track);
          while (controller.loading) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        }, () => client));
    expect(controller.lyrics?.isSynced, isTrue);
    expect(audio.playsFullSong, isFalse, reason: 'no Spotify: Deezer previews');

    await tester.pumpWidget(ProviderScope(
      overrides: [audioProvider.overrideWith((ref) => audio)],
      child: MaterialApp(
        home: Scaffold(body: LyricsLines(controller: controller, interactive: true)),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('fragmento de 30 s'), findsOneWidget);
    await tester.tap(find.text('Late line'));
    await tester.pump(const Duration(seconds: 1));
    expect(player.seeks, isEmpty, reason: '2:15 is past a 30 s preview: it would skip the song');

    controller.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
