import 'dart:io';

import 'package:flutter/services.dart';
import '../../core/logger.dart';


final _log = Log.named('Headphones');

/// Tells when the headphones are unplugged (or Bluetooth audio drops), so
/// the music pauses instead of carrying on out of the speaker. Android
/// sends this whichever app is playing, Spotify included.
class HeadphonesService {
  HeadphonesService._();

  static const _channel = EventChannel('com.tsuki.tsuki_tunes_mobile/noisy');

  static Stream<void>? _unplugged;

  static Stream<void> get unplugged {
    if (kIsWeb || !Platform.isAndroid) return const Stream.empty();
    return _unplugged ??= _channel
        .receiveBroadcastStream()
        .map<void>((_) {})
        .handleError((Object e) =>
            _log.fine('unplug events unavailable: $e'))
        .asBroadcastStream();
  }
}
