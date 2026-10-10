import 'dart:io';
import 'package:flutter/services.dart';

class ForegroundService {
  static const _channel =
      MethodChannel('com.tsuki.tsuki_tunes_mobile/foreground_service');

  static bool _isRunning = false;
  bool get isRunning => _isRunning;

  Future<void> start({String title = 'Tsuki Tunes', String artist = ''}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService', {
        'title': title,
        'artist': artist,
      });
      _isRunning = true;
    } on PlatformException {
      _isRunning = false;
    }
  }

  Future<void> updateNotification({required String title, required String artist}) async {
    if (!Platform.isAndroid || !_isRunning) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'artist': artist,
      });
    } on PlatformException {
      // ignore
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid || !_isRunning) return;
    try {
      await _channel.invokeMethod('stopService');
      _isRunning = false;
    } on PlatformException {
      // ignore
    }
  }
}
