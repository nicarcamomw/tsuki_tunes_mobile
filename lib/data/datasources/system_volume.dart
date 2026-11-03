import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../core/logger.dart';

final _log = Log.named('SystemVolume');

/// The phone's media volume, in Android's own steps.
abstract class SystemVolumeSource {
  /// Null when it can't be read (not Android, or no answer).
  Future<({int current, int max})?> read();
  Future<void> set(int index);
}

/// Android's media (music) volume, through MainActivity. The sleep timer
/// fades it when Spotify plays: Spotify's own volume can't be set on a
/// phone from another app.
class SystemVolume implements SystemVolumeSource {
  static const _channel = MethodChannel('com.tsuki.tsuki_tunes_mobile/device');

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<({int current, int max})?> read() async {
    if (!_supported) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, int>('mediaVolume');
      final current = raw?['current'];
      final max = raw?['max'];
      if (current == null || max == null || max <= 0) return null;
      return (current: current, max: max);
    } catch (e) {
      _log.fine('media volume unreadable: $e');
      return null;
    }
  }

  @override
  Future<void> set(int index) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('setMediaVolume', {'index': index});
    } catch (e) {
      _log.fine('media volume not set: $e');
    }
  }
}
