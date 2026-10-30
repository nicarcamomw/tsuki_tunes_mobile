import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/services/lyrics_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final lyrics = LyricsService();
  setUp(lyrics.clearCache);

  test('falls back to a search when the exact lookup misses', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      seen.add(req.url.path);
      expect(req.headers['User-Agent'], startsWith('TsukiTunes/'));
      if (req.url.path == '/api/get') return _json({'code': 404}, 404);
      return _json([
        {'trackName': 'Other Song', 'artistName': 'Bad Bunny', 'syncedLyrics': '[00:01.00] no'},
        {'trackName': 'Un Coco', 'artistName': 'Someone Else', 'syncedLyrics': '[00:01.00] no'},
        {'trackName': 'UN COCO', 'artistName': 'Bad Bunny', 'plainLyrics': 'plain'},
        {'trackName': 'Un Coco (Live)', 'artistName': 'Bad Bunny', 'syncedLyrics': '[00:02.00] yes'},
      ]);
    });

    final result = await http.runWithClient(() => lyrics.getLyrics('Un Coco', 'Bad Bunny'), () => client);
    expect(seen, ['/api/get', '/api/search']);
    expect(result?.isSynced, isTrue);
    expect(result!.lines.single.text, 'yes');

    // Cached: no new requests.
    await http.runWithClient(() => lyrics.getLyrics('Un Coco', 'Bad Bunny'), () => client);
    expect(seen.length, 2);
  });

  test('keeps at most 150 songs in memory', () async {
    final client = MockClient((_) async => _json({'plainLyrics': 'la la'}));
    await http.runWithClient(() async {
      for (var i = 0; i < 160; i++) {
        await lyrics.getLyrics('Song $i', 'Artist');
      }
    }, () => client);
    expect(lyrics.cachedCount, 150);
  });
}
