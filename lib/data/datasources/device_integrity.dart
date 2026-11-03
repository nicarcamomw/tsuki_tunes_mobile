import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import 'crash_reporter.dart';
import 'product_analytics.dart';

final _log = Log.named('DeviceIntegrity');

/// Whether this phone looks rooted or is an emulator.
///
/// Only reported, never acted on: Crashlytics keys on every launch (so a
/// crash says what kind of device it came from) and one analytics event per
/// install (to know how many there are). On-device checks are easy to hide
/// and custom ROMs trip them, so blocking on them would mostly hurt honest
/// users; Play Integrity through Firebase App Check is what guards the
/// backend (README, "Seguridad").
class DeviceIntegrity {
  const DeviceIntegrity({
    required this.rooted,
    required this.emulator,
    required this.signals,
  });

  final bool rooted;
  final bool emulator;

  /// Which signs were seen, comma-separated: su, test_keys, root_app.
  final String signals;

  static const _channel = MethodChannel('com.tsuki.tsuki_tunes_mobile/device');
  static const reportedKey = 'device_integrity_reported';

  /// Null off Android or when the platform side can't answer.
  static Future<DeviceIntegrity?> check({bool? android}) async {
    if (!(android ?? (!kIsWeb && Platform.isAndroid))) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('integrity');
      if (raw == null) return null;
      return DeviceIntegrity(
        rooted: raw['rooted'] == true,
        emulator: raw['emulator'] == true,
        signals: raw['signals'] as String? ?? '',
      );
    } catch (e) {
      _log.fine('integrity check unavailable: $e');
      return null;
    }
  }

  /// Checks and reports; see the class comment.
  static Future<void> report({bool? android}) async {
    final result = await check(android: android);
    if (result == null) return;
    CrashReporter.instance
      ..setKey('device_rooted', result.rooted)
      ..setKey('device_emulator', result.emulator)
      ..setKey('device_root_signals', result.signals);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(reportedKey) == true) return;
      ProductAnalytics.instance.log('device_integrity', {
        'rooted': result.rooted,
        'emulator': result.emulator,
      });
      await prefs.setBool(reportedKey, true);
    } catch (e) {
      _log.fine('integrity event not sent: $e');
    }
  }
}
