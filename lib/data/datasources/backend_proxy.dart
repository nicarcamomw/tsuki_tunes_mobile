import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/firebase_emulators.dart';
import '../../core/logger.dart';

final _log = Log.named('Backend');

/// Tsuki's own backend (Cloud Functions, `functions/src`): a proxy for
/// Last.fm, whose key lives on the server and never in the app, and for
/// Deezer on the web (cache, rate limit, and the CORS Deezer lacks).
///
/// The function is the Firebase project's (dev or prod, by flavor), at
/// `https://us-central1-<project>.cloudfunctions.net/api`; with the
/// emulators, the PC's.
class BackendProxy {
  BackendProxy._();
  static final BackendProxy instance = BackendProxy._();

  static const String region = 'us-central1';

  /// Tests point it at their own server; null asks Firebase.
  @visibleForTesting
  static String? baseUrlOverride;

  /// Where the function answers; null before Firebase is up (or in tests).
  String? get baseUrl {
    final override = baseUrlOverride;
    if (override != null) return override;
    if (Firebase.apps.isEmpty) return null;
    final project = Firebase.app().options.projectId;
    if (useFirebaseEmulators) {
      return 'http://$firebaseEmulatorHost:5001/$project/$region/api';
    }
    return 'https://$region-$project.cloudfunctions.net/api';
  }

  bool get isAvailable => baseUrl != null;

  /// [path] under the function (`lastfm`, `deezer/artist/27`) with [query].
  Uri? uri(String path, [Map<String, String> query = const {}]) {
    final base = baseUrl;
    if (base == null) return null;
    final u = Uri.parse('$base/$path');
    return query.isEmpty ? u : u.replace(queryParameters: query);
  }

  /// The proxy URL for a Deezer API URL (api.deezer.com/...), keeping its
  /// path and query; null when the backend isn't available.
  Uri? deezer(String deezerUrl) {
    final u = Uri.parse(deezerUrl);
    final path = u.path.replaceFirst(RegExp(r'^/+'), '');
    return uri('deezer/$path', u.queryParameters);
  }

  /// The App Check token proves the request comes from the real app; the
  /// function only requires it once enforcement is turned on.
  Future<Map<String, String>> _headers() async {
    try {
      final token = await FirebaseAppCheck.instance
          .getToken()
          .timeout(const Duration(seconds: 3));
      if (token != null && token.isNotEmpty) return {'X-Firebase-AppCheck': token};
    } catch (_) {
      // No App Check (emulators, web, debug without a registered token).
    }
    return const {};
  }

  /// GETs [path] from the function; null when it can't be reached.
  Future<http.Response?> get(
    String path,
    Map<String, String> query, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final target = uri(path, query);
    if (target == null) return null;
    return getUri(target, timeout: timeout);
  }

  Future<http.Response?> getUri(Uri target,
      {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      return await http.get(target, headers: await _headers()).timeout(timeout);
    } catch (e) {
      _log.warning('backend unreachable (${target.path}): $e');
      return null;
    }
  }
}
