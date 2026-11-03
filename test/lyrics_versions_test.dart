import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/lyrics_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/synced_lyrics.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('reading LRC', () {
    test('a line with several timestamps is placed at each', () {
      final l = SyncedLyrics.fromLrc('[00:10.00]Verse\n[00:20.00][01:05.50]Chorus\n[00:40.00]Bridge');
      expect([for (final x in l.lines) x.text], ['Verse', 'Chorus', 'Bridge', 'Chorus']);
      expect(l.lines.last.time, const Duration(minutes: 1, seconds: 5, milliseconds: 500));
      expect(l.plainLyrics, isNot(contains('[')));
    });

    test('timestamps with 1, 2 or 3 decimals, or none, and one-digit minutes', () {
      final l = SyncedLyrics.fromLrc('[0:01.5]a\n[00:02.25]b\n[00:03.125]c\n[00:04]d');
      expect([for (final x in l.lines) x.time.inMilliseconds], [1500, 2250, 3125, 4000]);
    });

    test('a timestamp with no words is an instrumental break', () {
      final l = SyncedLyrics.fromLrc('[00:05.00]Sing\n[00:10.00]\n[00:30.00]Again');
      expect(l.lines, hasLength(2));
      expect(l.inBreakAt(const Duration(seconds: 7)), isFalse, reason: 'still singing');
      expect(l.inBreakAt(const Duration(seconds: 15)), isTrue, reason: 'the solo');
      expect(l.activeIndexAt(const Duration(seconds: 15)), 0, reason: 'the scroll stays there');
      expect(l.inBreakAt(const Duration(seconds: 31)), isFalse);
    });

    test('[offset:] moves every line earlier (or later when negative)', () {
      final earlier = SyncedLyrics.fromLrc('[offset:+500]\n[00:10.00]a');
      expect(earlier.lines.single.time, const Duration(milliseconds: 9500));
      final later = SyncedLyrics.fromLrc('[offset:-250]\n[00:10.00]a');
      expect(later.lines.single.time, const Duration(milliseconds: 10250));
    });

    test('metadata tags are not lines', () {
      final l = SyncedLyrics.fromLrc('[ar:Artist]\n[ti:Title]\n[length:03:20]\n[00:01.00]Only line');
      expect([for (final x in l.lines) x.text], ['Only line']);
    });
  });

  group('the version of the song', () {
    final lyrics = LyricsService();
    setUp(lyrics.clearCache);

    test('the exact lookup asks for the song\'s length', () async {
      Uri? asked;
      final client = MockClient((req) async {
        if (req.url.path == '/api/get') {
          asked = req.url;
          return _json({'syncedLyrics': '[00:01.00]hi'});
        }
        return _json([]);
      });
      await http.runWithClient(
          () => lyrics.getLyrics('Song', 'Artist', durationSeconds: 215), () => client);
      expect(asked?.queryParameters['duration'], '215');
    });

    test('a 30 s length (a preview\'s, Deezer\'s default) is not sent', () async {
      Uri? asked;
      final client = MockClient((req) async {
        if (req.url.path == '/api/get') asked = req.url;
        return req.url.path == '/api/get' ? _json({'plainLyrics': 'x'}) : _json([]);
      });
      await http.runWithClient(
          () => lyrics.getLyrics('Song', 'Artist', durationSeconds: 30), () => client);
      expect(asked?.queryParameters.containsKey('duration'), isFalse);
    });

    test('the search picks the synced version closest in length', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/get') return _json({'code': 404}, 404);
        return _json([
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 180, 'syncedLyrics': '[00:01.00]radio edit'},
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 241, 'syncedLyrics': '[00:01.00]album'},
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 300, 'syncedLyrics': '[00:01.00]live'},
        ]);
      });
      final result = await http.runWithClient(
          () => lyrics.getLyrics('Song', 'Artist', durationSeconds: 240), () => client);
      expect(result!.lines.single.text, 'album');
    });

    test('plain lyrics beat synced ones of a clearly different version', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/get') return _json({'code': 404}, 404);
        return _json([
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 400, 'syncedLyrics': '[00:01.00]extended mix'},
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 240, 'plainLyrics': 'right words'},
        ]);
      });
      final result = await http.runWithClient(
          () => lyrics.getLyrics('Song', 'Artist', durationSeconds: 240), () => client);
      expect(result!.isSynced, isFalse);
      expect(result.plainLyrics, 'right words');
    });

    test('with no other choice, the far synced version still shows', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/get') return _json({'code': 404}, 404);
        return _json([
          {'trackName': 'Song', 'artistName': 'Artist', 'duration': 400, 'syncedLyrics': '[00:01.00]only one'},
        ]);
      });
      final result = await http.runWithClient(
          () => lyrics.getLyrics('Song', 'Artist', durationSeconds: 240), () => client);
      expect(result!.lines.single.text, 'only one');
    });
  });
}
