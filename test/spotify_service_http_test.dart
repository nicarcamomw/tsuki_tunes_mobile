import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsuki_tunes_mobile/data/datasources/spotify_service.dart';

/// SpotifyService against a fake Spotify Web API: what it sends and how it
/// reads the answers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late List<http.Request> sent;
  late Future<http.Response> Function(http.Request) api;

  http.Response json200(Object body) => http.Response(jsonEncode(body), 200);
  final noContent = http.Response('', 204);

  Future<T> withApi<T>(Future<T> Function() body) => http.runWithClient(
        body,
        () => MockClient((req) {
          sent.add(req);
          return api(req);
        }),
      );

  /// A service signed in with a token valid for an hour.
  Future<SpotifyService> signedIn({
    Duration expiresIn = const Duration(hours: 1),
    Map<String, dynamic>? profile,
  }) async {
    secure['spotify_access_token'] = 'tok';
    secure['spotify_refresh_token'] = 'refresh';
    secure['spotify_token_expiry'] =
        DateTime.now().add(expiresIn).millisecondsSinceEpoch.toString();
    if (profile != null) secure['spotify_profile'] = jsonEncode(profile);
    final s = SpotifyService();
    await withApi(s.loadSavedState);
    return s;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secure = {};
    sent = [];
    api = (_) async => http.Response('', 404);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return secure[key];
          case 'write':
            secure[key!] = args['value'] as String;
            return null;
          case 'delete':
            secure.remove(key);
            return null;
          case 'containsKey':
            return secure.containsKey(key);
        }
        return null;
      },
    );
  });

  group('session', () {
    test('a saved session is restored, with its profile', () async {
      final s = await signedIn(profile: {
        'display_name': 'Nico',
        'product': 'premium',
        'images': [
          {'url': 'https://i/1.jpg'},
        ],
      });

      expect(s.isConnected, isTrue);
      expect(s.accessToken, 'tok');
      expect(s.isPremium, isTrue);
      expect(s.displayName, 'Nico');
      expect(s.profileImage, 'https://i/1.jpg');
      expect(sent, isEmpty);
    });

    test('an expired token is refreshed on load', () async {
      api = (req) async {
        expect(req.url.toString(), 'https://accounts.spotify.com/api/token');
        expect(req.bodyFields['grant_type'], 'refresh_token');
        expect(req.bodyFields['refresh_token'], 'refresh');
        return json200({'access_token': 'new', 'refresh_token': 'r2', 'expires_in': 3600});
      };
      final s = await signedIn(expiresIn: const Duration(minutes: -1));

      expect(s.accessToken, 'new');
      expect(secure['spotify_access_token'], 'new');
      expect(secure['spotify_refresh_token'], 'r2');
    });

    test('a revoked refresh token signs out of Spotify', () async {
      api = (_) async => http.Response(jsonEncode({'error': 'invalid_grant'}), 400);
      final s = await signedIn(expiresIn: const Duration(minutes: -1));

      expect(s.isConnected, isFalse);
      expect(secure, isEmpty);
    });

    test('a refresh failing on the server keeps the session', () async {
      api = (_) async => http.Response('down', 503);
      final s = await signedIn(expiresIn: const Duration(minutes: -1));

      expect(s.isConnected, isTrue);
    });

    test('the profile is read and remembered', () async {
      final s = await signedIn();
      api = (req) async {
        expect(req.url.path, '/v1/me');
        expect(req.headers['Authorization'], 'Bearer tok');
        return json200({'display_name': 'Nico', 'product': 'free'});
      };
      await withApi(s.refreshProfile);

      expect(s.displayName, 'Nico');
      expect(s.isPremium, isFalse);
      expect(jsonDecode(secure['spotify_profile']!)['product'], 'free');
    });

    test('disconnecting forgets everything', () async {
      final s = await signedIn();
      await s.disconnect();

      expect(s.isConnected, isFalse);
      expect(secure, isEmpty);
    });

    test('signed out, nothing is sent', () async {
      final s = SpotifyService();
      await withApi(() async {
        expect(await s.pause(), isFalse);
        expect(await s.resume(), isFalse);
        expect(await s.seekTo(1000), isFalse);
        expect(await s.setRepeat('off'), isFalse);
        expect(await s.skipNext(), isFalse);
        expect(await s.skipPrevious(), isFalse);
        expect(await s.play(trackUri: 'spotify:track:x'), isFalse);
        expect(await s.getDevices(), isEmpty);
        expect(await s.getActiveDeviceId(), isNull);
        expect(await s.getPlaybackState(), isNull);
        expect(await s.nextInQueue(), isNull);
      });
      expect(sent, isEmpty);
    });
  });

  group('search', () {
    Map<String, dynamic> item(String name, String artist, String uri) => {
          'name': name,
          'uri': uri,
          'artists': [
            {'name': artist},
          ],
        };

    test('an ISRC match wins and is cached', () async {
      final s = await signedIn();
      api = (req) async {
        expect(req.url.queryParameters['q'], 'isrc:USRC1');
        return json200({
          'tracks': {
            'items': [item('Song', 'Band', 'spotify:track:isrc')],
          },
        });
      };

      final uri = await withApi(() => s.searchTrack('Song', 'Band', trackId: 'd1', isrc: 'USRC1'));
      expect(uri, 'spotify:track:isrc');

      sent.clear();
      expect(await withApi(() => s.searchTrack('Song', 'Band', trackId: 'd1')), uri);
      expect(await s.cachedTrackUri('Song', 'Band', trackId: 'd1'), uri);
      expect(sent, isEmpty);
    });

    test('title and artist must match, tags and accents aside', () async {
      final s = await signedIn();
      api = (req) async => json200({
            'tracks': {
              'items': [
                item('Another Song', 'Band', 'spotify:track:wrong'),
                item('Canción', 'Someone Else', 'spotify:track:wrong2'),
                item('Cancion - Remastered 2011', 'Band', 'spotify:track:ok'),
              ],
            },
          });

      expect(await withApi(() => s.searchTrack('Canción', 'Band')), 'spotify:track:ok');
      expect(sent.first.url.queryParameters['q'], 'track:Canción artist:Band');
    });

    test('the simple query is tried when the structured one finds nothing', () async {
      final s = await signedIn();
      api = (req) async {
        final q = req.url.queryParameters['q']!;
        if (q.startsWith('track:')) return json200({'tracks': {'items': []}});
        return json200({
          'tracks': {
            'items': [item('Song', 'Band', 'spotify:track:2nd')],
          },
        });
      };

      expect(await withApi(() => s.searchTrack('Song', 'Band')), 'spotify:track:2nd');
      expect(sent, hasLength(2));
    });

    test('no reliable match gives nothing', () async {
      final s = await signedIn();
      api = (_) async => json200({
            'tracks': {
              'items': [item('Different', 'Someone', 'spotify:track:x')],
            },
          });

      expect(await withApi(() => s.searchTrack('Song', 'Band')), isNull);
    });

    test('an expired token met in a search is refreshed and the search repeated', () async {
      final s = await signedIn();
      var searches = 0;
      api = (req) async {
        if (req.url.host == 'accounts.spotify.com') {
          return json200({'access_token': 'new', 'expires_in': 3600});
        }
        if (searches++ == 0) return http.Response('', 401);
        expect(req.headers['Authorization'], 'Bearer new');
        return json200({
          'tracks': {
            'items': [item('Song', 'Band', 'spotify:track:after')],
          },
        });
      };

      expect(await withApi(() => s.searchTrack('Song', 'Band')), 'spotify:track:after');
    });

    test('normalizeTitle drops versions and featured artists', () {
      expect(SpotifyService.normalizeTitle('Song (feat. X) - Live'),
          SpotifyService.normalizeTitle('song'));
    });
  });

  group('devices', () {
    final devices = {
      'devices': [
        {'id': 'tv', 'type': 'TV', 'name': 'TV', 'is_active': true},
        {'id': 'phone', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': false},
      ],
    };

    test('the phone is preferred, and its name kept', () async {
      final s = await signedIn();
      api = (_) async => json200(devices);

      expect(await withApi(s.getActiveDeviceId), 'phone');
      expect(s.activeDeviceName, 'Pixel');
      expect(await withApi(s.getDevices), hasLength(2));
    });

    test('with no devices, none', () async {
      final s = await signedIn();
      api = (_) async => json200({'devices': []});

      expect(await withApi(s.getActiveDeviceId), isNull);
      expect(s.activeDeviceName, isNull);
    });

    test('an inactive phone gets playback transferred to it', () async {
      final s = await signedIn();
      api = (req) async {
        if (req.method == 'GET') return json200(devices);
        expect(req.url.path, '/v1/me/player');
        expect(jsonDecode(req.body), {
          'device_ids': ['phone'],
          'play': false,
        });
        return noContent;
      };

      expect(await withApi(s.ensureActiveDevice), 'phone');
      expect(sent.where((r) => r.method == 'PUT'), hasLength(1));
    });
  });

  group('playback', () {
    final activePhone = {
      'devices': [
        {'id': 'phone', 'type': 'Smartphone', 'name': 'Pixel', 'is_active': true},
      ],
    };

    test('a list plays on the phone, from a position', () async {
      final s = await signedIn();
      api = (req) async {
        if (req.method == 'GET') return json200(activePhone);
        expect(req.url.path, '/v1/me/player/play');
        expect(req.url.queryParameters['device_id'], 'phone');
        expect(jsonDecode(req.body), {
          'uris': ['spotify:track:a', 'spotify:track:b'],
          'position_ms': 5000,
        });
        return noContent;
      };

      expect(
          await withApi(() => s.play(
              trackUris: ['spotify:track:a', 'spotify:track:b'], positionMs: 5000)),
          isTrue);

      // The phone is remembered: the next play doesn't list devices.
      sent.clear();
      api = (_) async => noContent;
      expect(await withApi(() => s.play(trackUri: 'spotify:track:c')), isTrue);
      expect(sent.single.url.queryParameters['device_id'], 'phone');
    });

    test('a remembered phone that is gone is looked up again', () async {
      final s = await signedIn();
      var plays = 0;
      api = (req) async {
        if (req.method == 'GET') return json200(activePhone);
        plays++;
        return plays == 2 ? http.Response('', 404) : noContent;
      };
      await withApi(() => s.play(trackUri: 'spotify:track:a'));

      expect(await withApi(() => s.play(trackUri: 'spotify:track:b')), isTrue);
      expect(plays, 3);
    });

    test('no phone: nothing plays', () async {
      final s = await signedIn();
      api = (_) async => json200({'devices': []});

      expect(await withApi(() => s.play(trackUri: 'spotify:track:a')), isFalse);
    });

    test('a refused play is retried once after a transfer', () async {
      final s = await signedIn();
      var plays = 0;
      api = (req) async {
        if (req.method == 'GET') return json200(activePhone);
        if (req.url.path == '/v1/me/player') return noContent;
        plays++;
        return plays == 1 ? http.Response('', 502) : noContent;
      };

      expect(await withApi(() => s.play(trackUri: 'spotify:track:a', deviceId: 'phone')), isTrue);
      expect(sent.map((r) => r.url.path), [
        '/v1/me/player/play',
        '/v1/me/player',
        '/v1/me/player/play',
      ]);
    });

    test('a 401 on play is retried with the token', () async {
      final s = await signedIn();
      var plays = 0;
      api = (req) async => plays++ == 0 ? http.Response('', 401) : noContent;

      expect(await withApi(() => s.play(trackUri: 'spotify:track:a', deviceId: 'phone')), isTrue);
      expect(plays, 2);
    });

    test('pause, seek, repeat and skips hit their endpoints', () async {
      final s = await signedIn();
      api = (_) async => noContent;

      await withApi(() async {
        expect(await s.pause(), isTrue);
        expect(await s.seekTo(42000), isTrue);
        expect(await s.setRepeat('track'), isTrue);
        expect(await s.skipNext(), isTrue);
        expect(await s.skipPrevious(), isTrue);
      });
      expect(sent.map((r) => '${r.method} ${r.url.path}?${r.url.query}'), [
        'PUT /v1/me/player/pause?',
        'PUT /v1/me/player/seek?position_ms=42000',
        'PUT /v1/me/player/repeat?state=track',
        'POST /v1/me/player/next?',
        'POST /v1/me/player/previous?',
      ]);
    });

    test('failures are reported as such', () async {
      final s = await signedIn();
      api = (_) async => http.Response('', 500);

      await withApi(() async {
        expect(await s.pause(), isFalse);
        expect(await s.seekTo(1), isFalse);
        expect(await s.setRepeat('off'), isFalse);
        expect(await s.skipNext(), isFalse);
        expect(await s.skipPrevious(), isFalse);
      });
    });

    test('network errors are caught', () async {
      final s = await signedIn();
      api = (_) async => throw http.ClientException('offline');

      await withApi(() async {
        expect(await s.pause(), isFalse);
        expect(await s.resume(), isFalse);
        expect(await s.seekTo(1), isFalse);
        expect(await s.setRepeat('off'), isFalse);
        expect(await s.skipNext(), isFalse);
        expect(await s.skipPrevious(), isFalse);
        expect(await s.play(trackUri: 'x', deviceId: 'phone'), isFalse);
        expect(await s.getDevices(), isEmpty);
        expect(await s.getActiveDeviceId(), isNull);
        expect(await s.transferPlayback('phone'), isFalse);
        expect(await s.getPlaybackState(), isNull);
        expect(s.lastPlaybackStateFailed, isTrue);
        expect(await s.nextInQueue(), isNull);
        expect(await s.searchTrack('Song', 'Band'), isNull);
      });
    });

    test('resume goes to the remembered phone, or looks it up', () async {
      final s = await signedIn();
      api = (req) async => req.method == 'GET' ? json200(activePhone) : noContent;

      // Nothing remembered yet: looked up.
      expect(await withApi(s.resume), isTrue);
      expect(sent.first.method, 'GET');

      sent.clear();
      expect(await withApi(s.resume), isTrue);
      expect(sent.single.url.queryParameters['device_id'], 'phone');

      // Gone: looked up again.
      sent.clear();
      var first = true;
      api = (req) async {
        if (req.method == 'GET') return json200(activePhone);
        if (first) {
          first = false;
          return http.Response('', 404);
        }
        return noContent;
      };
      expect(await withApi(s.resume), isTrue);
      expect(sent.map((r) => r.method), ['PUT', 'GET', 'PUT']);
    });
  });

  group('playback state', () {
    test('the current playback is read', () async {
      final s = await signedIn();
      api = (_) async => json200({
            'is_playing': true,
            'item': {'uri': 'spotify:track:a'},
          });

      final state = await withApi(s.getPlaybackState);
      expect(state?['is_playing'], isTrue);
      expect(s.lastPlaybackStateFailed, isFalse);
    });

    test('no session (204) is not a failure', () async {
      final s = await signedIn();
      api = (_) async => noContent;

      expect(await withApi(s.getPlaybackState), isNull);
      expect(s.lastPlaybackStateFailed, isFalse);
    });

    test('a server error is a failure', () async {
      final s = await signedIn();
      api = (_) async => http.Response('', 503);

      expect(await withApi(s.getPlaybackState), isNull);
      expect(s.lastPlaybackStateFailed, isTrue);
    });

    test('the next song in Spotify\'s queue', () async {
      final s = await signedIn();
      api = (req) async {
        expect(req.url.path, '/v1/me/player/queue');
        return json200({
          'currently_playing': {'uri': 'spotify:track:now'},
          'queue': [
            {'uri': 'spotify:track:next'},
            {'uri': 'spotify:track:later'},
          ],
        });
      };
      expect(await withApi(s.nextInQueue), 'spotify:track:next');

      api = (_) async => json200({'queue': []});
      expect(await withApi(s.nextInQueue), isNull);

      api = (_) async => http.Response('', 500);
      expect(await withApi(s.nextInQueue), isNull);
    });
  });
}
