import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_strings.dart';
import '../../core/logger.dart';
import '../../domain/entities/play_day.dart';
import '../../domain/entities/track.dart';
import '../repositories/library_repository_impl.dart';
import 'release_radar_service.dart';


final _log = Log.named('TimeMachine');

enum TimeMachineKind {
  /// From the play log: what was on repeat.
  plays,

  /// From first listens only: what you discovered.
  discoveries,
}

class TimeMachineTrack {
  final Track track;

  /// Plays in the window (0 for discoveries).
  final int count;
  final DateTime? discoveredAt;

  const TimeMachineTrack(this.track, {this.count = 0, this.discoveredAt});
}

class TimeMachineMoment {
  final DateTime anchor;
  final bool exactDay;
  final TimeMachineKind kind;
  final List<TimeMachineTrack> tracks;

  const TimeMachineMoment({
    required this.anchor,
    required this.exactDay,
    required this.kind,
    required this.tracks,
  });

  TimeMachineTrack get hero => tracks.first;

  /// "You couldn't stop listening" needs a real repeat, not a single play.
  bool get onRepeat => kind == TimeMachineKind.plays && hero.count >= 3;
}

/// "What were you listening to a year ago?" Builds moments from the play
/// log (counts) and falls back to first listens (discoveries). Also keeps a
/// small local schedule so the daily background job, which has no Firebase,
/// can send an occasional anniversary notification.
class TimeMachineService {
  static final TimeMachineService _instance = TimeMachineService._();
  factory TimeMachineService() => _instance;
  TimeMachineService._();

  static const int windowDays = 3;
  static const String _scheduleKey = 'tsuki_tm_schedule';
  static const String _scheduleBuiltKey = 'tsuki_tm_schedule_built';
  static const String _lastNotifiedKey = 'tsuki_tm_last_notified';
  static const String notifyKey = 'tsuki_tm_notify';
  static const int _notificationId = 7201;
  static const String payload = 'time_machine';
  static const Duration _minGapBetweenNotifications = Duration(days: 6);
  static const int _scheduleDays = 21;

  // ---------------------------------------------------------------------------
  // Dates
  // ---------------------------------------------------------------------------

  static int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Same calendar day [months] back; Mar 31 - 1 month is Feb 28/29.
  static DateTime monthsAgo(DateTime from, int months) {
    final total = from.year * 12 + (from.month - 1) - months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final maxDay = _daysIn(year, month);
    return DateTime(year, month, from.day > maxDay ? maxDay : from.day);
  }

  static DateTime yearsAgo(DateTime from, int years) =>
      monthsAgo(from, years * 12);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------------------------------------------------------------------------
  // Building a moment (pure)
  // ---------------------------------------------------------------------------

  /// Best moment around [anchor]: plays on that exact day, else plays that
  /// week, else discoveries that day, else that week. Null if nothing.
  static TimeMachineMoment? build({
    required DateTime anchor,
    required List<PlayDay> days,
    required List<ListenedTrackData> listened,
  }) {
    final day = _dateOnly(anchor);
    final from = day.subtract(const Duration(days: windowDays));
    final to = day.add(const Duration(days: windowDays));
    final dayKey = PlayDay.keyFor(day);

    final exactPlays = _fromPlays(days.where((d) => d.date == dayKey));
    final weekPlays = _fromPlays(days.where((d) {
      final k = d.date;
      return k.compareTo(PlayDay.keyFor(from)) >= 0 &&
          k.compareTo(PlayDay.keyFor(to)) <= 0;
    }));
    final exactFound = _fromListens(listened, day, day);
    final weekFound = _fromListens(listened, from, to);

    TimeMachineMoment moment(List<TimeMachineTrack> t, bool exact, TimeMachineKind k) =>
        TimeMachineMoment(anchor: day, exactDay: exact, kind: k, tracks: t);

    // A strong repeat that week beats a lone play on the exact day.
    if (exactPlays.isNotEmpty && exactPlays.first.count >= 2) {
      return moment(exactPlays, true, TimeMachineKind.plays);
    }
    if (weekPlays.isNotEmpty && weekPlays.first.count >= 3) {
      return moment(weekPlays, false, TimeMachineKind.plays);
    }
    if (exactPlays.isNotEmpty) return moment(exactPlays, true, TimeMachineKind.plays);
    if (exactFound.isNotEmpty) {
      return moment(exactFound, true, TimeMachineKind.discoveries);
    }
    if (weekPlays.isNotEmpty) return moment(weekPlays, false, TimeMachineKind.plays);
    if (weekFound.isNotEmpty) {
      return moment(weekFound, false, TimeMachineKind.discoveries);
    }
    return null;
  }

  static List<TimeMachineTrack> _fromPlays(Iterable<PlayDay> days) {
    final counts = <String, int>{};
    final meta = <String, PlayDayTrack>{};
    for (final d in days) {
      d.plays.forEach((id, c) => counts.update(id, (v) => v + c, ifAbsent: () => c));
      meta.addAll(d.tracks);
    }
    final ids = counts.keys.where((id) => meta[id] != null).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      for (final id in ids.take(25))
        TimeMachineTrack(meta[id]!.toTrack(), count: counts[id]!),
    ];
  }

  static List<TimeMachineTrack> _fromListens(
      List<ListenedTrackData> listened, DateTime from, DateTime to) {
    final end = to.add(const Duration(days: 1));
    final found = listened
        .where((t) =>
            t.listenedAt != null &&
            !t.listenedAt!.isBefore(from) &&
            t.listenedAt!.isBefore(end))
        .toList()
      ..sort((a, b) => a.listenedAt!.compareTo(b.listenedAt!));
    return [
      for (final t in found.take(25))
        TimeMachineTrack(
          Track(
            id: t.trackId,
            title: t.title,
            artistId: '',
            artistName: t.artistName,
            albumId: t.albumId,
            albumTitle: t.albumTitle,
            coverUrl: t.coverUrl,
            previewUrl: t.previewUrl,
            durationSeconds: t.duration > 0 ? t.duration : 30,
          ),
          discoveredAt: t.listenedAt,
        ),
    ];
  }

  /// Days that have any history, for "random day" travel.
  static List<DateTime> datesWithHistory(
      List<ListenedTrackData> listened, DateTime before) {
    final cutoff = _dateOnly(before);
    final set = <String>{
      for (final t in listened)
        if (t.listenedAt != null && t.listenedAt!.isBefore(cutoff))
          PlayDay.keyFor(t.listenedAt!),
    };
    return set.map(DateTime.parse).toList()..sort();
  }

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
