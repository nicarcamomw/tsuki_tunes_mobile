import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  /// Whether to offer letting Tsuki run in the background: Android limits
  /// its battery (so locking the phone can stop the music mid-song) and the
  /// user wasn't asked yet. Asked once, answered either way.
  Future<bool> shouldOfferBackground() async {
    if (!Platform.isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedBackgroundKey) ?? false) return false;
      return !(await _channel.invokeMethod<bool>('runsInBackground') ?? true);
    } catch (e) {
      _log.severe('background check failed: $e');
      return false;
    }
  }

  /// Android's own dialog to let Tsuki run in the background (after the
  /// user read why, PermissionPrimer). Not offered again.
  Future<void> askToRunInBackground() async {
    await _markBackgroundAsked();
    try {
      await _channel.invokeMethod<bool>('askToRunInBackground');
    } catch (e) {
      _log.severe('background request failed: $e');
    }
  }

  /// "Not now": not offered again on its own (the battery guide stays).
  Future<void> declineBackground() => _markBackgroundAsked();

  Future<void> _markBackgroundAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedBackgroundKey, true);
    } catch (_) {}
  }

  /// Opens Tsuki's own page in Android's settings (notifications, battery,
  /// permissions), for when Android won't ask again.
  Future<bool> openTsukiSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await PackageInfo.fromPlatform();
      return await _channel.invokeMethod<bool>('openAppSettings', {'package': info.packageName}) ?? false;
    } catch (e) {
      _log.severe('opening Tsuki settings failed: $e');
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
