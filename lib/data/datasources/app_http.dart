import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The app's HTTP requests, over one shared client (perf).
///
/// The package's top-level functions (`http.get` and the rest) make a new
/// client for every request and close it after, so each one opened a new
/// connection: a TCP and TLS handshake (a few hundred milliseconds on
/// mobile data) before every search, album, artist page and lyrics lookup.
/// One client keeps its connections open between requests (keep-alive), so
/// the next request to the same host goes out at once.
///
/// Under `flutter test` each request makes its client as before, so the
/// tests' `http.runWithClient` fakes still answer.
abstract final class AppHttp {
  static final bool _underTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static final http.Client _shared = http.Client();

  static Future<T> _with<T>(Future<T> Function(http.Client client) request) async {
    if (!_underTest) return request(_shared);
    final client = http.Client();
    try {
      return await request(client);
    } finally {
      client.close();
    }
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _with((c) => c.get(url, headers: headers));

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _with((c) => c.post(url, headers: headers, body: body, encoding: encoding));

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _with((c) => c.put(url, headers: headers, body: body, encoding: encoding));
}
