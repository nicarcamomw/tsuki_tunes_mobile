import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_precache_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';

// C3: the upcoming songs' previews (~1.3 MB for three) are downloaded ahead
// of time; "Precarga solo con Wi-Fi" (Settings > Storage) skips that on
// mobile data. Playback itself still streams.

class _Network extends ChangeNotifier implements ConnectivityProvider {
  _Network({required this.metered});
  bool metered;

  @override
  bool get isOnline => true;

  @override
  bool get isMetered => metered;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends AudioPlayerService {
  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {}
}

Track _song(String id) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Band',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: 'https://cdn.example.com/preview_$id.mp3',
      durationSeconds: 180,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('tsuki_precache_wifi_test');
    AudioPrecacheService.cacheDirForTesting = dir;
    addTearDown(() {
      AudioPrecacheService.cacheDirForTesting = null;
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async {
      if (call.method == 'init') {
        messenger.setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.${(call.arguments as Map)['id']}'),
            (_) async => {});
      }
      return {};
    });
  });

  // Each run uses songs of its own: the precache remembers what it already
  // downloaded (it's one per app), and an earlier test must not count.
  var run = 0;

  /// Plays the first of four songs and returns the previews downloaded
  /// ahead of time, without the run prefix ('preview_s2.mp3').
  Future<List<String>> downloadsWhilePlaying({required bool wifiOnly, required bool metered}) async {
    final tag = 'r${++run}';
    SharedPreferences.setMockInitialValues({'tsuki_precache_wifi_only': wifiOnly});
    final downloads = <String>[];
    final cdn = MockClient((req) async {
      // Only the previews; the radio and related artists ask Deezer too.
      if (req.url.host != 'cdn.example.com') return http.Response('{"data":[]}', 200);
      downloads.add(req.url.pathSegments.last.replaceFirst('preview_$tag', 'preview_'));
      return http.Response.bytes(List.filled(15000, 1), 200);
    });
    await http.runWithClient(() async {
      final audio = AudioProvider(
          service: _Player(), storage: StorageService(), connectivityProvider: _Network(metered: metered));
      await audio.setPrecacheWifiOnly(wifiOnly);
      final queue = [for (var i = 1; i <= 4; i++) _song('${tag}s$i')];
      await audio.playTrack(queue.first, newQueue: queue);
      // The next song is downloaded at once; wait for it (up to 2 s, so a
      // busy machine running tests in parallel doesn't fail it).
      final until = DateTime.now().add(const Duration(seconds: 2));
      while (downloads.isEmpty && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }, () => cdn);
    return downloads;
  }

  test('on mobile data with the option on, nothing is downloaded ahead', () async {
    expect(await downloadsWhilePlaying(wifiOnly: true, metered: true), isEmpty);
  });

  test('on Wi-Fi with the option on, the next song is downloaded as always', () async {
    expect(await downloadsWhilePlaying(wifiOnly: true, metered: false), contains('preview_s2.mp3'));
  });

  test('with the option off, mobile data downloads ahead too (the default: fastest skips)', () async {
    expect(await downloadsWhilePlaying(wifiOnly: false, metered: true), contains('preview_s2.mp3'));
  });
}
