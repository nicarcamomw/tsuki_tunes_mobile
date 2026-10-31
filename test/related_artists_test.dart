import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/deezer_api_service.dart';

/// Deezer answer with [count] related artists for [artistId], plus the
/// artist itself, which must be filtered out.
String _relatedBody(String artistId, int count) => json.encode({
      'data': [
        for (var i = 0; i < count; i++) {'id': '${artistId}_$i', 'name': 'A$i'},
        {'id': artistId, 'name': 'Self'},
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = DeezerApiService();

  test('one request serves every limit, sliced, without the artist itself',
      () async {
    var requests = 0;
    final client = MockClient((req) async {
      requests++;
      expect(req.url.queryParameters['limit'], '25');
      return http.Response(_relatedBody('r1', 25), 200);
    });

    await http.runWithClient(() async {
      final twelve = await api.getRelatedArtists('r1', limit: 12);
      final twenty = await api.getRelatedArtists('r1');
      expect(twelve, hasLength(12));
      expect(twenty, hasLength(20));
      expect(twenty.any((a) => a.id == 'r1'), isFalse);
    }, () => client);

    expect(requests, 1);
  });

  test('concurrent callers share the in-flight request', () async {
    var requests = 0;
    final client = MockClient((req) async {
      requests++;
      await Future.delayed(const Duration(milliseconds: 20));
      return http.Response(_relatedBody('r2', 5), 200);
    });

    await http.runWithClient(() async {
      final results = await Future.wait([
        api.getRelatedArtists('r2', limit: 3),
        api.getRelatedArtists('r2', limit: 10),
      ]);
      expect(results[0], hasLength(3));
      expect(results[1], hasLength(5));
    }, () => client);

    expect(requests, 1);
  });

  test('a network failure throws only when asked, and is not cached',
      () async {
    var fail = true;
    final client = MockClient((req) async => fail
        ? http.Response('oops', 503)
        : http.Response(_relatedBody('r3', 4), 200));

    await http.runWithClient(() async {
      expect(await api.getRelatedArtists('r3'), isEmpty);
      await expectLater(
        api.getRelatedArtists('r3', throwOnError: true),
        throwsA(isA<DeezerApiException>()),
      );

      fail = false;
      expect(await api.getRelatedArtists('r3'), hasLength(4));
    }, () => client);
  });

  test('prefetch warms the cache so later calls make no request', () async {
    var requests = 0;
    final client = MockClient((req) async {
      requests++;
      final id = req.url.pathSegments[1];
      return http.Response(_relatedBody(id, 3), 200);
    });

    await http.runWithClient(() async {
      await api.prefetchRelatedArtists(['p1', 'p2']);
      expect(requests, 2);
      await api.getRelatedArtists('p1', limit: 12);
      await api.getRelatedArtists('p2');
    }, () => client);

    expect(requests, 2);
  });
}
