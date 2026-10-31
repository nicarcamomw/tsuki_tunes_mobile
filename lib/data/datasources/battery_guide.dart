import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playback_error.dart';

/// Phone makers whose battery manager freezes apps in the background, each
/// with its own settings to undo it. Sister brands share their system.
enum BatteryFamily {
  /// Honor (MagicOS) and Huawei (EMUI).
  honor,

  /// Xiaomi, Redmi and POCO (MIUI / HyperOS).
  xiaomi,

  /// OPPO, realme and OnePlus (ColorOS and its forks).
  oppo,
}

/// The maker's family for [manufacturer] / [brand] (Android's
/// Build.MANUFACTURER and Build.BRAND), or null when it doesn't freeze apps.
@visibleForTesting
BatteryFamily? batteryFamilyFor(String manufacturer, String brand) {
  final names = '${manufacturer.toLowerCase()} ${brand.toLowerCase()}';
  bool has(String name) => names.contains(name);
  if (has('honor') || has('huawei')) return BatteryFamily.honor;
  if (has('xiaomi') || has('redmi') || has('poco')) return BatteryFamily.xiaomi;
  if (has('oppo') || has('realme') || has('oneplus')) return BatteryFamily.oppo;
  return null;
}

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
      debugPrint('[BatteryGuide] maker lookup failed: $e');
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
      debugPrint('[BatteryGuide] opening Spotify settings failed: $e');
      return false;
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
