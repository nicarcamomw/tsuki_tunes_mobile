import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/repositories/playback_controller.dart';
import 'rain_mix_service.dart';

class TileChannelService {
  static const _channel = MethodChannel('com.tsuki.tsuki_tunes_mobile/tile');

  static PlaybackController? _player;
  static bool _initialized = false;

  static void init(PlaybackController player) {
    _player = player;
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleCall);
    _checkPendingAction();
  }

  static Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'playRainMix':
      case 'rain_mix':
        await _playRainMix();
        return true;
      case 'isPlaying':
        return _player?.isPlaying ?? false;
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'Unknown method: ${call.method}',
        );
    }
  }

  static Future<void> _checkPendingAction() async {
    try {
      final action = await _channel.invokeMethod<String>('getPendingAction');
      if (action == 'rain_mix') {
        await _playRainMix();
      }
    } catch (_) {}
  }

  static Future<void> _playRainMix() async {
    final audio = _player;
    if (audio == null) return;

    try {
      final tracks = await RainMixService().getTracks();
      if (tracks.isEmpty) {
        debugPrint('[TileChannel] No rain mix tracks found');
        return;
      }
      await audio.playTrack(tracks.first, newQueue: tracks);
    } catch (e) {
      debugPrint('[TileChannel] Rain mix playback failed: $e');
    }
  }
}
