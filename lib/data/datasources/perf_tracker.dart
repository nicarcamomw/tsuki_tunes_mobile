import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One timed span: a custom trace or an HTTP request.
abstract class PerfSpan {
  void attribute(String name, String value);
  void stop({int? responseCode, int? responseBytes});
}

/// Where timings go: Firebase Performance in the app, a fake in tests.
abstract class PerfBackend {
  PerfSpan trace(String name);
  PerfSpan request(Uri url, String method);
}

class FirebasePerfBackend implements PerfBackend {
  FirebasePerfBackend(this._performance);
  final FirebasePerformance _performance;

  @override
  PerfSpan trace(String name) => _TraceSpan(_performance.newTrace(name));

  @override
  PerfSpan request(Uri url, String method) => _HttpSpan(_performance.newHttpMetric(
      url.toString(),
      switch (method) {
        'POST' => HttpMethod.Post,
        'PUT' => HttpMethod.Put,
        'DELETE' => HttpMethod.Delete,
        _ => HttpMethod.Get,
      }));
}

class _TraceSpan implements PerfSpan {
  _TraceSpan(this._trace) {
    _started = _trace.start().catchError((Object _) {});
  }
  final Trace _trace;
  late final Future<void> _started;

  @override
  void attribute(String name, String value) => _trace.putAttribute(name, value);

  @override
  void stop({int? responseCode, int? responseBytes}) {
    _started.then((_) => _trace.stop()).catchError((Object _) {});
  }
}

class _HttpSpan implements PerfSpan {
  _HttpSpan(this._metric) {
    _started = _metric.start().catchError((Object _) {});
  }
  final HttpMetric _metric;
  late final Future<void> _started;

  @override
  void attribute(String name, String value) => _metric.putAttribute(name, value);

  @override
  void stop({int? responseCode, int? responseBytes}) {
    _metric
      ..httpResponseCode = responseCode
      ..responsePayloadSize = responseBytes;
    _started.then((_) => _metric.stop()).catchError((Object _) {});
  }
}

class _NoSpan implements PerfSpan {
  const _NoSpan();
  @override
  void attribute(String name, String value) {}
  @override
  void stop({int? responseCode, int? responseBytes}) {}
}

/// How long the things users wait on take, in Firebase Performance: the
/// time from a song being picked to its first sound, waking Spotify, and
/// each request to Deezer and Spotify. Requests are recorded by endpoint
/// only: the query (a search's words) never leaves the phone. Until
/// Firebase Performance is attached (after Firebase starts; never in
/// tests) nothing is timed.
class PerfTracker {
  PerfTracker._();
  static final PerfTracker instance = PerfTracker._();

  PerfBackend? _backend;

  void attach(PerfBackend backend) => _backend = backend;

  /// Starts a custom trace; [PerfSpan.stop] sends it, and one never stopped
  /// (the song changed first) is never sent.
  PerfSpan start(String name) => _backend?.trace(name) ?? const _NoSpan();

  /// Sends [send]'s request through, timing it as a request to [url]'s
  /// endpoint.
  Future<http.Response> request(
      String method, Uri url, Future<http.Response> Function() send) async {
    final backend = _backend;
    if (backend == null) return send();
    final span = backend.request(endpointOf(url), method);
    try {
      final response = await send();
      span.stop(
          responseCode: response.statusCode,
          responseBytes: response.bodyBytes.length);
      return response;
    } catch (_) {
      // Timed out or no connection: no response to report.
      span.stop();
      rethrow;
    }
  }

  /// [url] without its query or fragment.
  static Uri endpointOf(Uri url) =>
      Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null, path: url.path);

  @visibleForTesting
  void resetForTesting() => _backend = null;
}
