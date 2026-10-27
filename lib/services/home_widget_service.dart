import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/moon_phase.dart';
import '../models/track.dart';

class HomeWidgetService {
  static const _playerWidget = 'TsukiPlayerWidgetProvider';
  static const _lunaWidget = 'TsukiLunaWidgetProvider';

  static final HomeWidgetService _instance = HomeWidgetService._();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    HomeWidget.setAppGroupId('com.tsuki.tsuki_tunes_mobile');
    await _updateMoonPhase();
  }

  Future<void> registerInteractivityCallback() async {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }

  Future<void> updateTrack(Track? track, {required bool isPlaying}) async {
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
  final action = uri.host;
  debugPrint('[HomeWidget] background callback: $action');
}
