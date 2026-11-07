import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';
import '../../core/logger.dart';
import '../../domain/entities/notification_payloads.dart';
import '../../domain/entities/play_day.dart';
import '../../domain/logic/time_machine.dart';
import '../repositories/library_repository_impl.dart';
import 'release_radar_service.dart';

export '../../domain/logic/time_machine.dart'
    show TimeMachineKind, TimeMachineMoment, TimeMachineTrack;


final _log = Log.named('TimeMachine');

/// "What were you listening to a year ago?" Builds moments from the play
/// log (counts) and falls back to first listens (discoveries). Also keeps a
/// small local schedule so the daily background job, which has no Firebase,
/// can send an occasional anniversary notification.
class TimeMachineService {
  static final TimeMachineService _instance = TimeMachineService._();
  factory TimeMachineService() => _instance;
  TimeMachineService._();

  static const String _scheduleKey = 'tsuki_tm_schedule';
  static const String _scheduleBuiltKey = 'tsuki_tm_schedule_built';
  static const String _lastNotifiedKey = 'tsuki_tm_last_notified';
  static const String notifyKey = 'tsuki_tm_notify';
  static const int _notificationId = 7201;
  static const String payload = NotificationPayloads.timeMachine;
  static const Duration _minGapBetweenNotifications = Duration(days: 6);
  static const int _scheduleDays = 21;

  static const int windowDays = TimeMachine.windowDays;

  /// See [TimeMachine.monthsAgo].
  static DateTime monthsAgo(DateTime from, int months) =>
      TimeMachine.monthsAgo(from, months);
  static DateTime yearsAgo(DateTime from, int years) =>
      TimeMachine.yearsAgo(from, years);
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// See [TimeMachine.build].
  static TimeMachineMoment? build({
    required DateTime anchor,
    required List<PlayDay> days,
    required List<ListenedTrackData> listened,
  }) =>
      TimeMachine.build(anchor: anchor, days: days, listened: listened);

  static List<DateTime> datesWithHistory(
          List<ListenedTrackData> listened, DateTime before) =>
      TimeMachine.datesWithHistory(listened, before);

  // ---------------------------------------------------------------------------
  // Foreground: load data and refresh the notification schedule
  // ---------------------------------------------------------------------------

  Future<TimeMachineMoment?> load(LibraryRepositoryImpl library, DateTime anchor) async {
    final day = _dateOnly(anchor);
    final days = await library.loadPlayDays(
      day.subtract(const Duration(days: windowDays)),
      day.add(const Duration(days: windowDays)),
    );
    return build(anchor: day, days: days, listened: library.listenedTracks);
  }

  /// Precomputes anniversaries for the next few weeks (at most once a day),
  /// so the background job can notify without Firebase.
  Future<void> refreshSchedule(LibraryRepositoryImpl library) async {
    if (!ReleaseRadarService.isSupported || !library.listenedTracksLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateOnly(DateTime.now());
      if (prefs.getString(_scheduleBuiltKey) == PlayDay.keyFor(today)) return;

      final firstAnchor = yearsAgo(today, 1);
      final lastAnchor =
          yearsAgo(today.add(const Duration(days: _scheduleDays)), 1);
      final days = await library.loadPlayDays(
        firstAnchor.subtract(const Duration(days: windowDays)),
        lastAnchor.add(const Duration(days: windowDays)),
      );

      final schedule = <String, Map<String, dynamic>>{};
      for (var i = 0; i <= _scheduleDays; i++) {
        final date = today.add(Duration(days: i));
        final m = build(
            anchor: yearsAgo(date, 1), days: days, listened: library.listenedTracks);
        if (m == null || !_worthNotifying(m)) continue;
        schedule[PlayDay.keyFor(date)] = {
          'kind': m.kind.name,
          'repeat': m.onRepeat,
          'count': m.hero.count,
          'title': m.hero.track.title,
          'artist': m.hero.track.artistName,
        };
      }
      await prefs.setString(_scheduleKey, json.encode(schedule));
      await prefs.setString(_scheduleBuiltKey, PlayDay.keyFor(today));
    } catch (e) {
      _log.severe('refreshSchedule failed: $e');
    }
  }

  /// "Occasional" means a moment that's actually memorable: a song on
  /// repeat, or a day when you discovered several songs.
  static bool _worthNotifying(TimeMachineMoment m) =>
      m.kind == TimeMachineKind.plays ? m.hero.count >= 3 : m.tracks.length >= 3;

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notifyKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notifyKey, enabled);
  }

  // ---------------------------------------------------------------------------
  // Background (no Firebase): occasional anniversary notification
  // ---------------------------------------------------------------------------

  Future<void> runBackgroundCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (!(prefs.getBool(notifyKey) ?? true)) return;

      final now = DateTime.now();
      final last = DateTime.tryParse(prefs.getString(_lastNotifiedKey) ?? '');
      if (last != null && now.difference(last) < _minGapBetweenNotifications) {
        return;
      }

      final raw = prefs.getString(_scheduleKey);
      if (raw == null) return;
      final entry = (json.decode(raw) as Map)[PlayDay.keyFor(now)];
      if (entry is! Map) return;

      final strings = AppStrings(ReleaseRadarService.languageFromPrefs(prefs));
      final title = '${entry['title'] ?? ''}';
      final artist = '${entry['artist'] ?? ''}';
      final repeat = entry['repeat'] == true;
      final count = entry['count'] is num ? (entry['count'] as num).toInt() : 0;

      await ReleaseRadarService().showLocalNotification(
        id: _notificationId,
        title: repeat
            ? strings.timeMachineNotifRepeat(title)
            : entry['kind'] == TimeMachineKind.plays.name
                ? strings.timeMachineNotifPlayed(title)
                : strings.timeMachineNotifDiscovered(title),
        body: repeat ? strings.timeMachineNotifRepeatBody(artist, count) : artist,
        payload: payload,
        channelId: 'tsuki_time_machine',
        channelName: strings.timeMachineChannelName,
        channelDescription: strings.timeMachineChannelDescription,
      );
      await prefs.setString(_lastNotifiedKey, now.toIso8601String());
    } catch (e) {
      _log.severe('background check failed: $e');
    }
  }
}
