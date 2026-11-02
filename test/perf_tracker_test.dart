import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsuki_tunes_mobile/data/datasources/perf_tracker.dart';

class FakeSpan implements PerfSpan {
  FakeSpan(this.name);
  final String name;
  final attributes = <String, String>{};
  bool stopped = false;
  int? code;
  int? bytes;

  @override
  void attribute(String name, String value) => attributes[name] = value;

  @override
  void stop({int? responseCode, int? responseBytes}) {
    stopped = true;
    code = responseCode;
    bytes = responseBytes;
  }
}

class FakePerf implements PerfBackend {
  final spans = <FakeSpan>[];

  @override
  PerfSpan trace(String name) => _add(FakeSpan(name));

  @override
  PerfSpan request(Uri url, String method) => _add(FakeSpan('$method $url'));

  FakeSpan _add(FakeSpan span) {
    spans.add(span);
    return span;
  }
}

void main() {
  final tracker = PerfTracker.instance;
  late FakePerf perf;

  setUp(() {
    tracker.resetForTesting();
    perf = FakePerf();
  });
  tearDown(tracker.resetForTesting);

  test('requests are recorded by endpoint, without the query', () {
    expect(
      PerfTracker.endpointOf(Uri.parse('https://api.deezer.com/search?q=toxicity%20soad&limit=25')),
      Uri.parse('https://api.deezer.com/search'),
    );
  });

  test('a request is timed with its response code and size', () async {
    tracker.attach(perf);
    final res = await tracker.request('GET', Uri.parse('https://api.spotify.com/v1/search?q=x'),
        () async => http.Response('{"ok":true}', 200));

    expect(res.statusCode, 200);
    final span = perf.spans.single;
    expect(span.name, 'GET https://api.spotify.com/v1/search');
    expect(span.stopped, isTrue);
    expect(span.code, 200);
    expect(span.bytes, 11);
  });

  test('a request that fails stops its timing and still throws', () async {
    tracker.attach(perf);
    await expectLater(
      tracker.request('GET', Uri.parse('https://api.deezer.com/track/1'),
          () async => throw http.ClientException('offline')),
      throwsA(isA<http.ClientException>()),
    );
    expect(perf.spans.single.stopped, isTrue);
    expect(perf.spans.single.code, isNull);
  });

  test('before Firebase starts, requests just go through', () async {
    final res = await tracker.request('GET', Uri.parse('https://api.deezer.com/track/1'),
        () async => http.Response('', 204));
    expect(res.statusCode, 204);
    expect(perf.spans, isEmpty);
  });
}
