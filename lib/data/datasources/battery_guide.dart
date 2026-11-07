import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/battery_family.dart';
import '../../domain/entities/playback_error.dart';

export '../../domain/entities/battery_family.dart';


final _log = Log.named('BatteryGuide');

/// When Spotify can't play because the phone froze it in the background,
/// explains how to let it run, on the phones known to do that.
class BatteryGuide {
  BatteryGuide._();
  static final BatteryGuide instance = BatteryGuide._();

  static const _channel = MethodChannel('com.tsuki.tsuki_tunes_mobile/device');
  static const _dismissedKey = 'battery_guide_dismissed';
  static const spotifyPackage = 'com.spotify.music';

  BatteryFamily? _family;
  String _makerName = '';
  bool _dismissed = false;

  BatteryFamily? get family => _family;

  /// The maker as the phone names it ("Redmi", "HONOR"), for the texts.
  String get makerName => _makerName;

  /// Reads the phone's maker and whether the guide was turned off. Until it
  /// finishes, the guide is never offered.
  Future<void> load() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed = prefs.getBool(_dismissedKey) ?? false;
      final maker = await _channel.invokeMapMethod<String, String>('maker');
      final manufacturer = maker?['manufacturer'] ?? '';
      final brand = maker?['brand'] ?? '';
      _family = batteryFamilyFor(manufacturer, brand);
      _makerName = brand.isNotEmpty ? brand : manufacturer;
    } catch (e) {
      _log.severe('maker lookup failed: $e');
    }
  }

  /// Only when Spotify failed because it couldn't start playing (the phone
  /// froze it), on a phone known to do that, unless turned off.
  bool offerFor(SpotifyFallbackReason? reason) =>
      reason == SpotifyFallbackReason.openApp && _family != null && !_dismissed;

  /// Opens Spotify's app settings page, where its battery options are.
  Future<bool> openSpotifySettings() async {
    try {
      return await _channel.invokeMethod<bool>(
              'openAppSettings', {'package': spotifyPackage}) ??
          false;
    } catch (e) {
      _log.severe('opening Spotify settings failed: $e');
      return false;
    }
  }

  static const _askedBackgroundKey = 'asked_run_in_background';

  /// Once, the first time music plays: asks Android (its own dialog) to let
  /// Tsuki run in the background. Without it, many phones kill Tsuki when
  /// the screen locks, and the music stops or Spotify's player takes over
  /// the lock screen.
  Future<void> askToRunInBackgroundOnce() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedBackgroundKey) ?? false) return;
      if (await _channel.invokeMethod<bool>('runsInBackground') ?? true) return;
      await prefs.setBool(_askedBackgroundKey, true);
      await _channel.invokeMethod<bool>('askToRunInBackground');
    } catch (e) {
      _log.severe('background request failed: $e');
    }
  }

  Future<void> dismiss() async {
    _dismissed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissedKey, true);
    } catch (_) {}
  }

  @visibleForTesting
  void setForTesting({BatteryFamily? family, String makerName = '', bool dismissed = false}) {
    _family = family;
    _makerName = makerName;
    _dismissed = dismissed;
  }
}
