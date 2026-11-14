import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../core/logger.dart';

final _log = Log.named('Screen');

/// Tells when the screen turns on (true) or off (false), whichever app is
/// in front, so the lock screen can be set up just as it shows.
class ScreenService {
  ScreenService._();

  static const _channel = EventChannel('com.tsuki.tsuki_tunes_mobile/screen');
  static const _unlockChannel = EventChannel('com.tsuki.tsuki_tunes_mobile/unlock');

  static Stream<bool>? _changes;
  static Stream<bool>? _unlocked;

  /// Whether the phone can be used: true when it's on and unlocked, false
  /// when off or on the lock screen. Starts with the current state.
  static Stream<bool> get unlocked {
    if (kIsWeb || !Platform.isAndroid) return const Stream.empty();
    return _unlocked ??= _unlockChannel
        .receiveBroadcastStream()
        .map<bool>((on) => on == true)
        .handleError((Object e) => _log.fine('unlock events unavailable: $e'))
        .asBroadcastStream();
  }

  static Stream<bool> get changes {
    if (kIsWeb || !Platform.isAndroid) return const Stream.empty();
    return _changes ??= _channel
        .receiveBroadcastStream()
        .map<bool>((on) => on == true)
        .handleError((Object e) => _log.fine('screen events unavailable: $e'))
        .asBroadcastStream();
  }
}
