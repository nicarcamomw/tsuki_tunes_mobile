import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/backend_proxy.dart';
import 'package:tsuki_tunes_mobile/data/datasources/lastfm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const base = 'https://us-central1-tsuki-test.cloudfunctions.net/api';

  setUp(() => BackendProxy.baseUrlOverride = base);
  tearDown(() => BackendProxy.baseUrlOverride = null);

  group('backend urls', () {
    test('a Deezer URL keeps its path and query under /deezer', () {
      final u = BackendProxy.instance
          .deezer('https://api.deezer.com/search/artist?q=korn&limit=25')!;
      expect(u.toString(), '$base/deezer/search/artist?q=korn&limit=25');
    });

    test('without Firebase (and no override) there is no backend', () {
      BackendProxy.baseUrlOverride = null;
      expect(BackendProxy.instance.baseUrl, isNull);
      expect(BackendProxy.instance.deezer('https://api.deezer.com/genre'), isNull);
    });
  });

  group('Last.fm through the backend', () {
    test('asks the proxy without any key and reads the answer', () async {
      final asked = <Uri>[];
      final client = MockClient((req) async {
        asked.add(req.url);
        return http.Response(
            '{"artist":{"tags":{"tag":[{"name":"nu metal"},{"name":"rock"}]}}}', 200);
      });
      final tags = await http.runWithClient(
          () => LastFmService.getArtistTags('Deftones'), () => client);
      expect(tags, ['nu metal', 'rock']);
      expect(asked.single.toString(), startsWith('$base/lastfm?'));
      expect(asked.single.queryParameters['method'], 'artist.getinfo');
      expect(asked.single.queryParameters['artist'], 'Deftones');
      expect(asked.single.queryParameters.containsKey('api_key'), isFalse);
    });

    test('similar songs and artist search parse the proxy\'s answers', () async {
      final client = MockClient((req) async => switch (req.url.queryParameters['method']) {
            'track.getsimilar' => http.Response(
                '{"similartracks":{"track":[{"name":"Change","artist":{"name":"Deftones"},"match":"0.9"}]}}',
                200),
            _ => http.Response(
                '{"results":{"artistmatches":{"artist":[{"name":"Metallica"}]}}}', 200),
          });
      final similar = await http.runWithClient(
          () => LastFmService.getSimilarTracks('Korn', 'Blind'), () => client);
      expect(similar.single.title, 'Change');
      expect(similar.single.match, 0.9);
      final names = await http.runWithClient(
          () => LastFmService.searchArtistNames('metalica'), () => client);
      expect(names, ['Metallica']);
    });

    test('a refusal (rate limit) is final: no retry, empty answer', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"error":"too many requests"}', 429);
      });
      final tags = await http.runWithClient(
          () => LastFmService.getArtistTags('Korn'), () => client);
      expect(tags, isEmpty);
      expect(calls, 1);
    });

    test('an unreachable backend and no key in the build: empty, no crash',
        () async {
      final client = MockClient((_) async => throw http.ClientException('offline'));
      final tags = await http.runWithClient(
          () => LastFmService.getArtistTags('Korn'), () => client);
      expect(tags, isEmpty);
    });
  });
}
