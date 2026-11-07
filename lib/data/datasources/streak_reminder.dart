import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';
import '../../domain/entities/notification_payloads.dart';
import 'release_radar_service.dart';

/// The daily streak's one quiet reminder: at [hour] on the first day
/// without music, while there is a run of [minStreak] days or more to keep.
///
/// Music played before then moves it to the next day, so there is never
/// more than one a day, and none at all once the run is over. It makes no
/// sound and doesn't pop up.
class StreakReminder {
  StreakReminder({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final StreakReminder shared = StreakReminder();

  static const String enabledKey = 'tsuki_streak_reminder';
  static const int notificationId = 7103;
  static const String payload = NotificationPayloads.streak;
  static const int hour = 20;
  static const int minStreak = 2;

  final DateTime Function() _clock;

  /// [hour], for screens that only hold an instance.
  int get remindHour => hour;

  final ValueNotifier<bool> enabled = ValueNotifier(true);
  bool _loaded = false;

  /// What's scheduled now ('' for nothing), so a sync that changes nothing
  /// doesn't touch the system.
  String? _scheduled;
  Future<void> _queue = Future.value();

  /// When to remind a run of [streak] days whose last day with music is
  /// [lastDay] (an epoch day of local dates): [hour] the day after. Null
  /// when that's past or the run is too short to matter.
  static DateTime? remindAt({required int streak, required int lastDay, required DateTime now}) {
    if (streak < minStreak || lastDay <= 0) return null;
    final next = DateTime.fromMillisecondsSinceEpoch((lastDay + 1) * 86400000, isUtc: true);
    final at = DateTime(next.year, next.month, next.day, hour);
    return at.isAfter(now) ? at : null;
  }

  /// Sets the reminder for [run] (null: no run alive). Calls queue up.
  Future<void> sync(({int streak, int lastDay})? run) => _queue = _queue.then((_) => _sync(run));

  Future<void> setEnabled(bool value, ({int streak, int lastDay})? run) async {
    enabled.value = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledKey, value);
    } catch (_) {}
    if (value) await ReleaseRadarService().requestPermission();
    await sync(run);
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(enabledKey) ?? true;
    } catch (_) {}
  }

  Future<void> _sync(({int streak, int lastDay})? run) async {
    if (!ReleaseRadarService.isSupported) return;
    await load();
    final at = enabled.value && run != null
        ? remindAt(streak: run.streak, lastDay: run.lastDay, now: _clock())
        : null;
    final key = at == null ? '' : '${run!.streak}@${at.toIso8601String()}';
    if (key == _scheduled) return;
    _scheduled = key;
    final radar = ReleaseRadarService();
    if (at == null) {
      await radar.cancelNotification(notificationId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final strings = AppStrings(ReleaseRadarService.languageFromPrefs(prefs));
    await radar.scheduleQuietNotification(
      id: notificationId,
      at: at,
      title: strings.streakNotifTitle(run!.streak),
      body: strings.streakNotifBody,
      payload: payload,
      channelId: 'tsuki_streak',
      channelName: strings.streakChannelName,
      channelDescription: strings.streakChannelDescription,
    );
  }
}
