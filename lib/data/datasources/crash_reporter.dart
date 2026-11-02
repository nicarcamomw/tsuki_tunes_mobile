import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Where reports go: Crashlytics in the app, a fake in tests.
abstract class CrashReporterBackend {
  Future<void> setKey(String key, Object value);
  Future<void> log(String message);
  Future<void> recordNonFatal(Object error, StackTrace stack, String reason);
}

class CrashlyticsBackend implements CrashReporterBackend {
  CrashlyticsBackend(this._crashlytics);
  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  Future<void> recordNonFatal(Object error, StackTrace stack, String reason) =>
      _crashlytics.recordError(error, stack, reason: reason, fatal: false);
}

/// Something that went wrong without crashing (Spotify fell back to the
/// preview, App Remote couldn't be reached), reported so silent failures
/// show up in Crashlytics, grouped by where they happened.
class PlaybackIssue implements Exception {
  PlaybackIssue(this.reason);
  final String reason;

  @override
  String toString() => 'PlaybackIssue: $reason';
}

/// What Crashlytics gets beyond the crash itself: custom keys (the state of
/// playback when it happened), breadcrumbs (the playback events before it)
/// and non-fatal issues. Song titles, searches and device names never leave
/// the phone: breadcrumbs go through [redact], and keys carry ids, not names.
/// Until Crashlytics is attached (after Firebase starts, never in tests)
/// keys are kept and sent on [attach]; the rest is dropped.
class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  CrashReporterBackend? _backend;
  final Map<String, Object> _keys = {};
  final Map<String, DateTime> _lastIssue = {};

  /// The same issue is reported at most this often, so one broken state
  /// doesn't fill a session's report with copies of itself.
  static const issueInterval = Duration(minutes: 10);

  void attach(CrashReporterBackend backend) {
    _backend = backend;
    _keys.forEach((key, value) => _send(() => backend.setKey(key, value)));
  }

  /// Sets [key] in the next reports; repeats of the same value send nothing.
  void setKey(String key, Object value) {
    if (_keys[key] == value) return;
    _keys[key] = value;
    final backend = _backend;
    if (backend != null) _send(() => backend.setKey(key, value));
  }

  void breadcrumb(String message) {
    final backend = _backend;
    if (backend != null) _send(() => backend.log(redact(message)));
  }

  /// Reports [reason] as a non-fatal issue, grouped by where this is called.
  void issue(String reason) {
    final backend = _backend;
    if (backend == null) return;
    final now = DateTime.now();
    final last = _lastIssue[reason];
    if (last != null && now.difference(last) < issueInterval) return;
    _lastIssue[reason] = now;
    final stack = StackTrace.current;
    _send(() => backend.recordNonFatal(PlaybackIssue(reason), stack, reason));
  }

  void _send(Future<void> Function() call) {
    call().catchError((Object e) {
      // Reporting must never break the app; a debugPrint here would loop
      // back into breadcrumbs.
    });
  }

  static final _quoted = RegExp(r'"[^"]*"');
  static final _deviceName =
      RegExp(r'(device[:=]\s*|smartphone\s+|device=)[^,()\n]+', caseSensitive: false);

  /// [message] without what could identify what someone listens to or owns:
  /// quoted text (song titles, artists, searches) and Spotify device names.
  @visibleForTesting
  static String redact(String message) => message
      .replaceAll(_quoted, '"…"')
      .replaceAllMapped(_deviceName, (m) => '${m[1]}…');

  @visibleForTesting
  void resetForTesting() {
    _backend = null;
    _keys.clear();
    _lastIssue.clear();
  }
}
