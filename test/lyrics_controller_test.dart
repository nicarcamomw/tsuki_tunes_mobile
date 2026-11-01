import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsuki_tunes_mobile/data/datasources/lyrics_service.dart';
import 'package:tsuki_tunes_mobile/domain/entities/track.dart';
import 'package:tsuki_tunes_mobile/presentation/widgets/lyrics_view.dart';

const _track = Track(
  id: '1',
  title: 'Song',
  artistId: 'a',
  artistName: 'Artist',
  albumId: '',
  albumTitle: '',
  coverUrl: '',
  previewUrl: '',
  durationSeconds: 100,
);

void main() {
  setUp(() {
    LyricsService().clearCache();
    LyricsController.retryDelays = const [Duration(milliseconds: 10), Duration(milliseconds: 10)];
  });

  test('a failed load retries on its own instead of showing "no lyrics"', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (calls <= 2) throw http.ClientException('flaky'); // first attempt: both lookups fail
      if (req.url.path == '/api/get') {
        return http.Response.bytes(utf8.encode(jsonEncode({'plainLyrics': 'la la'})), 200);
      }
      return http.Response('[]', 200);
    });
    final controller = LyricsController();
    await http.runWithClient(() async {
      controller.ensureFor(_track);
      expect(controller.loading, isTrue);
      while (controller.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }, () => client);
    expect(controller.lyrics?.plainLyrics, 'la la');
    controller.dispose();
  });

  test('gives up after the retries and lets the user try again', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    final controller = LyricsController();
    await http.runWithClient(() async {
      controller.ensureFor(_track);
      while (controller.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }, () => client);
    expect(controller.lyrics, isNull);
    controller.dispose();
  });
}
