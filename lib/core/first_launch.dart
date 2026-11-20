import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first start after the app is installed on a phone.
///
/// That start alone pays for what the phone does only once: Android runs
/// the plugins' and Firebase's Java code uncompiled until it compiles it
/// later (on the main thread that also paces Flutter's frames), the GPU
/// driver compiles the app's shaders for the first time (they're kept on
/// disk after), and Firebase creates its local databases. The entrance and
/// the login stuttered under it, only that once.
///
/// So that start holds on the loading screen ("Preparando la luna…",
/// SessionGate preparing) while the app's services start and the frames
/// settle, and the login opens once the entrance has run smooth for a
/// moment ([settle]). Later starts never wait for this.
abstract final class FirstLaunch {
  static const String _key = 'tsuki_first_launch_done_v1';

  /// Whether this is the first start after install (known from [check]).
  static bool get isFirst => _isFirst;
  static bool _isFirst = false;

  static Completer<void>? _done;

  /// Completes when the first start is ready (at once on any other).
  static Future<void> get ready => _done?.future ?? Future<void>.value();

  /// Reads whether the app has started on this phone before.
  static Future<void> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFirst = !(prefs.getBool(_key) ?? false);
    } catch (_) {
      _isFirst = false;
    }
    if (_isFirst) _done = Completer<void>();
  }

  /// The first start is ready: the login (or the app) may open, and later
  /// starts won't wait.
  static Future<void> finish() async {
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  /// Makes this a first start (tests).
  @visibleForTesting
  static void debugStartFirst() {
    _isFirst = true;
    _done = Completer<void>();
  }

  /// Back to a usual start (tests).
  @visibleForTesting
  static void debugReset() {
    _isFirst = false;
    _done = null;
  }

  /// Waits until frames have run smooth for a while: [smoothFrames] in a
  /// row each built and drawn within [budget] (the loading screen animates
  /// all along, so there are frames to judge), at least [atLeast] and at
  /// most [atMost]. On a phone that's already warm this ends after
  /// [atLeast]; on a cold first start, once the one-time work has passed.
  static Future<void> settle({
    int smoothFrames = 36,
    Duration budget = const Duration(milliseconds: 14),
    Duration atLeast = const Duration(milliseconds: 1200),
    Duration atMost = const Duration(seconds: 7),
  }) async {
    final smooth = Completer<void>();
    var run = 0;
    void onTimings(List<FrameTiming> timings) {
      for (final t in timings) {
        final ok = t.buildDuration <= budget && t.rasterDuration <= budget;
        run = ok ? run + 1 : 0;
      }
      if (run >= smoothFrames && !smooth.isCompleted) smooth.complete();
    }

    SchedulerBinding.instance.addTimingsCallback(onTimings);
    try {
      await Future.wait([
        smooth.future.timeout(atMost, onTimeout: () {}),
        Future<void>.delayed(atLeast),
      ]);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
    }
  }
}
