import '../entities/listened_track.dart';
import '../entities/play_day.dart';
import '../entities/track.dart';

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

/// "What were you listening to a year ago?" as pure logic: the dates, and
/// the best moment around one from the play log and the first listens.
abstract final class TimeMachine {
  /// Days on each side of the anchor that still count as "that week".
  static const int windowDays = 3;

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
}
