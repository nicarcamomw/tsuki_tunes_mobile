import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart' show PlayerException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_player_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/audio_precache_service.dart';
import 'package:tsuki_tunes_mobile/data/datasources/storage_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/state/audio_provider.dart';
import 'package:tsuki_tunes_mobile/presentation/state/connectivity_provider.dart';

// B2: Deezer's preview links carry a signature that expires (hdnea=exp=…).
// Songs stored in playlists, history or a saved queue keep old links, so
// playback renews them, and a link refused anyway is renewed once more.

class _Online extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Plays whatever it's given, except links in [refused], which fail like a
/// 403 from Deezer's CDN.
class _Player extends AudioPlayerService {
  final played = <String>[];
  final refused = <String>{};

  @override
  Future<void> playTrack(Track track, {Duration? initialPosition, int maxRetries = 3}) async {
    played.add(track.previewUrl);
    if (refused.contains(track.previewUrl)) {
      throw PlayerException(403, 'Response code: 403', null);
    }
  }
}

int _secondsFromNow(Duration d) => DateTime.now().add(d).millisecondsSinceEpoch ~/ 1000;

String _link(String name, Duration expiresIn) =>
    'https://cdnt-preview.dzcdn.net/api/1/1/$name.mp3?hdnea=exp=${_secondsFromNow(expiresIn)}~acl=*~hmac=abc';

Track _track(String id, String previewUrl) => Track(
      id: id,
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Band',
      albumId: 'alb',
      albumTitle: 'Album',
      coverUrl: '',
      previewUrl: previewUrl,
      durationSeconds: 180,
    );

/// Deezer's /track/{id}, answering with [fresh] as the preview link.
MockClient _deezer(Map<String, String> fresh, List<String> asked) => MockClient((req) async {
      asked.add(req.url.toString());
      final id = req.url.pathSegments.last;
      if (req.url.host != 'api.deezer.com' || !fresh.containsKey(id)) {
        return http.Response('{"error":{"code":800}}', 200);
      }
      return http.Response(
          jsonEncode({
            'id': int.parse(id),
            'title': 'Song $id',
            'duration': 180,
            'preview': fresh[id],
            'artist': {'id': 1, 'name': 'Band'},
            'album': {'id': 2, 'title': 'Album', 'cover_medium': ''},
          }),
          200);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Its own previews folder: other test files use the shared one in parallel.
    final dir = Directory.systemTemp.createTempSync('tsuki_preview_refresh_test');
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
            MethodChannel('com.ryanheise.just_audio.methods.${call.arguments['id']}'),
            (_) async => {});
      }
      return {};
    });
  });


  AudioProvider audioWith(_Player player) =>
      AudioProvider(service: player, storage: StorageService(), connectivityProvider: _Online());

  group('playing a stored song', () {
    test('an expired link is renewed before playing, and the queue keeps the new one', () async {
      final player = _Player();
      final audio = audioWith(player);
      final stale = _link('old', const Duration(hours: -3));
      final fresh = _link('new', const Duration(hours: 2));
      final asked = <String>[];

      await http.runWithClient(
          () => audio.playTrack(_track('9001', stale)), () => _deezer({'9001': fresh}, asked));

      expect(player.played, [fresh]);
      expect(audio.currentTrack?.previewUrl, fresh);
      expect(audio.lastPlaybackError, isNull);
      expect(asked.where((u) => u.contains('/track/9001')), hasLength(1));
    });

    test('a link still valid is played as is, without asking Deezer', () async {
      final player = _Player();
      final audio = audioWith(player);
      final valid = _link('ok', const Duration(hours: 2));
      final asked = <String>[];

      await http.runWithClient(
          () => audio.playTrack(_track('9002', valid)), () => _deezer({}, asked));

      expect(player.played, [valid]);
      expect(asked.where((u) => u.contains('/track/')), isEmpty);
    });

    test('a link refused before its expiry is renewed and played once more', () async {
      final player = _Player();
      final audio = audioWith(player);
      final revoked = _link('revoked', const Duration(hours: 2));
      final fresh = _link('renewed', const Duration(hours: 2));
      player.refused.add(revoked);

      await http.runWithClient(
          () => audio.playTrack(_track('9003', revoked)), () => _deezer({'9003': fresh}, []));

      expect(player.played, [revoked, fresh]);
      expect(audio.currentTrack?.previewUrl, fresh);
      expect(audio.lastPlaybackError, isNull);
    });

    test('when Deezer has no newer link, it fails once instead of looping', () async {
      final player = _Player();
      final audio = audioWith(player);
      final revoked = _link('gone', const Duration(hours: 2));
      player.refused.add(revoked);

      await http.runWithClient(
          () => audio.playTrack(_track('9004', revoked)), () => _deezer({'9004': revoked}, []));

      expect(player.played, [revoked]);
      expect(audio.lastPlaybackError, isNotNull);
    });
  });

  group('pre-downloading the next song', () {
    test('a refused link is renewed once and the download succeeds', () async {
      final revoked = _link('pre_old', const Duration(hours: 2));
      final fresh = _link('pre_new', const Duration(hours: 2));
      final downloads = <String>[];
      final cdn = MockClient((req) async {
        downloads.add(req.url.toString());
        return req.url.toString() == fresh
            ? http.Response.bytes(List.filled(15000, 1), 200)
            : http.Response('', 403);
      });
      final track = _track('9005', revoked);

      await http.runWithClient(
          () => AudioPrecacheService()
              .precacheTrack(track, onStale: (t) async => t.copyWith(previewUrl: fresh)),
          () => cdn);

      expect(downloads, [revoked, fresh]);
      expect(AudioPrecacheService().getCachedFilePath('9005'), isNotNull);
    });

    test('without a fresher link, or for other failures, it gives up quietly', () async {
      final revoked = _link('pre_dead', const Duration(hours: 2));
      var downloads = 0;
      final cdn = MockClient((_) async {
        downloads++;
        return http.Response('', 403);
      });
      await http.runWithClient(
          () => AudioPrecacheService()
              .precacheTrack(_track('9006', revoked), onStale: (t) async => t),
          () => cdn);
      expect(downloads, 1);
      expect(AudioPrecacheService().getCachedFilePath('9006'), isNull);

      final down = MockClient((_) async {
        downloads++;
        return http.Response('', 500);
      });
      var renewed = false;
      await http.runWithClient(
          () => AudioPrecacheService().precacheTrack(_track('9007', revoked), onStale: (t) async {
                renewed = true;
                return t;
              }),
          () => down);
      expect(renewed, isFalse, reason: 'a server error is not a stale link');
    });
  });
}
