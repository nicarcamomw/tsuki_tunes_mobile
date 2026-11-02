import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Structured logging for Tsuki Tunes.
///
/// Every subsystem gets its own [Logger] through [Log.named]; messages carry
/// a severity level instead of a free-form `debugPrint`. In release builds
/// logging is off entirely (the root level is [Level.OFF]). In debug builds
/// every level prints, with the tag, level and message on one line so it
/// reads like the old `debugPrint('[Tag] …')` output.
///
/// Crashlytics breadcrumbs can listen on [Logger.root.onRecord] if we ever
/// want warnings/errors in crash reports.
///
/// ### Levels (from noisiest to most severe)
///
/// | Logger method | When to use |
/// |---|---|
/// | `fine`   | Trace: position syncs, prefetches, queue edits |
/// | `info`   | State changes worth knowing: headphones unplugged, crossfade started |
/// | `warning`| Caught errors that the app recovers from (fallback played, retry) |
/// | `severe` | Caught errors that lose functionality (init failures, stream errors) |
class Log {
  Log._();

  /// Call once, before any logger is used (in main, right after Firebase).
  static void init() {
    hierarchicalLoggingEnabled = true;
    Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
    Logger.root.onRecord.listen(_print);
  }

  /// Returns a named child logger. Calling it twice with the same name
  /// returns the same instance (package:logging does this internally).
  static Logger named(String name) => Logger(name);

  static void _print(LogRecord record) {
    // Short level tag: I/W/S for info/warning/severe, F for fine.
    final lvl = switch (record.level) {
      Level() when record.level == Level.FINE => 'F',
      Level() when record.level == Level.INFO => 'I',
      Level() when record.level == Level.WARNING => 'W',
      Level() when record.level >= Level.SEVERE => 'S',
      _ => record.level.name[0],
    };
    final line = '$lvl [${record.loggerName}] ${record.message}';
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
    // Also keep the debugPrint path so `flutter logs` / device logs show it.
    debugPrint(line);
  }
}
