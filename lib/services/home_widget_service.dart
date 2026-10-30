import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/moon_phase.dart';
import '../models/track.dart';

class HomeWidgetService {
  static const _playerWidget = 'TsukiPlayerWidgetProvider';
  static const _lunaWidget = 'TsukiLunaWidgetProvider';
  static const appGroupId = 'com.tsuki.tsuki_tunes_mobile';

  static final HomeWidgetService _instance = HomeWidgetService._();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._();

  bool _initialized = false;

  // Home screen widgets exist on Android and iOS only (Platform throws on web).
  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized || !_supported) return;
    _initialized = true;
    unawaited(HomeWidget.setAppGroupId(appGroupId));
    await _updateMoonPhase();
  }

  Future<void> registerInteractivityCallback() async {
    if (!_supported) return;
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }

  Future<void> updateTrack(Track? track, {required bool isPlaying}) async {
    if (!_initialized) return;
    try {
      await _writeTrack(track, isPlaying: isPlaying);
    } catch (e) {
      debugPrint('[HomeWidget] update failed: $e');
    }
  }

  Future<void> _writeTrack(Track? track, {required bool isPlaying}) async {
    await Future.wait([
      HomeWidget.saveWidgetData('track_title', track?.title ?? ''),
      HomeWidget.saveWidgetData(
        'track_artist',
        track?.fullArtistName ?? '',
      ),
      HomeWidget.saveWidgetData('track_cover', track?.coverUrl ?? ''),
      HomeWidget.saveWidgetData('album_title', track?.albumTitle ?? ''),
      HomeWidget.saveWidgetData('is_playing', isPlaying),
    ]);
    await _updateMoonPhase();
    await _refreshWidgets();
  }

  Future<void> updatePlayState(bool isPlaying) async {
    if (!_initialized) return;
    await HomeWidget.saveWidgetData('is_playing', isPlaying);
    await _refreshWidgets();
  }

  Future<void> _updateMoonPhase() async {
    final now = DateTime.now();
    final phase = MoonPhaseCalculator.phase(now);
    final illum = MoonPhaseCalculator.illumination(now);
    await Future.wait([
      HomeWidget.saveWidgetData(
        'moon_emoji',
        MoonPhaseCalculator.emoji(phase),
      ),
      HomeWidget.saveWidgetData(
        'moon_name_jp',
        MoonPhaseCalculator.japaneseName(phase),
      ),
      HomeWidget.saveWidgetData(
        'moon_name_en',
        MoonPhaseCalculator.englishName(phase),
      ),
      HomeWidget.saveWidgetData(
        'moon_illumination',
        (illum * 100).round(),
      ),
    ]);
  }

  Future<void> _refreshWidgets() async {
    await Future.wait([
      HomeWidget.updateWidget(androidName: _playerWidget),
      HomeWidget.updateWidget(androidName: _lunaWidget),
    ]);
  }
}

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  final host = uri.host;
  debugPrint('[HomeWidget] background action: $host');
  // Widget button taps arrive here. The actual playback control goes through
  // the system media session — audio_service's notification already provides
  // prev/play-pause/next on the lock-screen and notification shade, and the
  // widget buttons send the same MediaSession transport commands via the
  // Android MediaController API in TsukiPlayerWidgetProvider. This callback
  // handles any Flutter-side bookkeeping (currently none needed).
}
