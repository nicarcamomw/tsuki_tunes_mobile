import '../models/play_day.dart';
import '../models/wrapped_data.dart';
import '../providers/library_provider.dart';

class WrappedService {
  static final WrappedService _instance = WrappedService._internal();
  factory WrappedService() => _instance;
  WrappedService._internal();

  /// Below this many logged plays, counts are too thin to rank anything and
  /// the recap falls back to discoveries (first listens). A month needs
  /// fewer.
  static const int minPlaysForPlayBased = 30;
  static const int minPlaysForMonthly = 12;

  /// The recap of [year], or of one [month] (1–12) of it. [now] bounds the
  /// days the period has had so far.
  WrappedData generate({
    required List<PlayDay> days,
    required List<ListenedTrackData> listened,
    required int year,
    int? month,
    DateTime? now,
  }) {
    final prefix = month == null
        ? '$year-'
        : '$year-${month.toString().padLeft(2, '0')}-';
    final periodDays = days.where((d) => d.date.startsWith(prefix)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final plays = periodDays.fold<int>(0, (s, d) => s + d.totalPlays);
    final min = month == null ? minPlaysForPlayBased : minPlaysForMonthly;
    final data = plays >= min
        ? _fromPlays(periodDays, year)
        : generateFromDiscoveries(listened, year, month: month);
    return _withDays(data, periodDays, year, month, now ?? DateTime.now());
  }

  /// The listening profile of a recap: 'night', 'dawn', 'loyal',
  /// 'marathon', 'explorer' or 'balance'.
  static String auraOf(WrappedData d) {
    final total = d.hourDistribution.values.fold<int>(0, (s, v) => s + v);
    double share(List<int> hours) => total == 0
        ? 0
        : hours.fold<int>(0, (s, h) => s + (d.hourDistribution[h] ?? 0)) /
            total;
    final plays = d.totalTracksPlayed;
    if (share(const [22, 23, 0, 1, 2, 3, 4]) >= 0.35) return 'night';
    if (share(const [5, 6, 7, 8, 9]) >= 0.30) return 'dawn';
    if (d.topArtists.isNotEmpty &&
        plays > 0 &&
        d.topArtists.first.playCount / plays >= 0.3) {
      return 'loyal';
    }
    if (d.activeDays > 0 && plays / d.activeDays >= 25) return 'marathon';
    if (plays >= 20 && d.uniqueArtistsCount / plays >= 0.4) return 'explorer';
    return 'balance';
  }

  /// Share of plays in each part of the day: late night (0–5), morning
  /// (6–11), afternoon (12–18), evening (19–23).
  static List<double> dayParts(Map<int, int> hours) {
    final total = hours.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const [0, 0, 0, 0];
    double sum(int from, int to) {
      var n = 0;
      for (var h = from; h <= to; h++) {
        n += hours[h] ?? 0;
      }
      return n / total;
    }

    return [sum(0, 5), sum(6, 11), sum(12, 18), sum(19, 23)];
  }

  /// Total minutes listened in a period (for comparisons).
  int minutesIn(List<PlayDay> days, int year, {int? month}) {
    final prefix = month == null
        ? '$year-'
        : '$year-${month.toString().padLeft(2, '0')}-';
    return days
            .where((d) => d.date.startsWith(prefix))
            .fold<int>(0, (s, d) => s + d.seconds) ~/
        60;
  }

  WrappedData _withDays(WrappedData data, List<PlayDay> days, int year,
      int? month, DateTime now) {
    final start = DateTime(year, month ?? 1, 1);
    final end = month == null ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final today = DateTime(now.year, now.month, now.day + 1);
    final until = today.isBefore(end) ? today : end;
    final total = until.isAfter(start) ? until.difference(start).inDays : 0;
    final active = data.basedOnPlays
        ? days.where((d) => d.totalPlays > 0).length
        : data.activeDays;
    return WrappedData(
      year: year,
      month: month,
      activeDays: active,
      periodDays: total,
      topTracks: data.topTracks,
      topArtists: data.topArtists,
      totalMinutesListened: data.totalMinutesListened,
      totalTracksPlayed: data.totalTracksPlayed,
      uniqueTracksCount: data.uniqueTracksCount,
      uniqueArtistsCount: data.uniqueArtistsCount,
      favoriteHour: data.favoriteHour,
      hourDistribution: data.hourDistribution,
      funFacts: data.funFacts,
      generatedAt: data.generatedAt,
      basedOnPlays: data.basedOnPlays,
      playsSince: data.playsSince,
    );
  }

  WrappedData _empty(int year) => WrappedData(
        year: year,
        topTracks: const [],
        topArtists: const [],
        totalMinutesListened: 0,
        totalTracksPlayed: 0,
        uniqueTracksCount: 0,
        uniqueArtistsCount: 0,
        favoriteHour: 0,
        hourDistribution: const {},
        funFacts: const [],
        generatedAt: DateTime.now(),
      );

  // ---------------------------------------------------------------------------
  // From the play log: real counts
  // ---------------------------------------------------------------------------

  WrappedData _fromPlays(List<PlayDay> days, int year) {
    final tracks = <String, _PlayAgg>{};
    final hourDist = <int, int>{};
    var totalSeconds = 0;
    var totalPlays = 0;

    for (final day in days) {
      totalSeconds += day.seconds;
      day.hours.forEach((h, c) => hourDist.update(h, (v) => v + c, ifAbsent: () => c));
      for (final e in day.plays.entries) {
        final meta = day.tracks[e.key] ??
            PlayDayTrack(id: e.key, title: '', artistName: '');
        final agg = tracks.putIfAbsent(e.key, () => _PlayAgg(meta));
        if (meta.title.isNotEmpty) agg.meta = meta; // days are oldest first
        agg.plays += e.value;
        agg.seconds += e.value * meta.durationSeconds;
        totalPlays += e.value;
      }
    }
    if (totalPlays == 0) return _empty(year);

    final ranked = tracks.values.toList()
      ..sort((a, b) {
        final c = b.plays.compareTo(a.plays);
        return c != 0 ? c : b.seconds.compareTo(a.seconds);
      });
    final topTracks = [
      for (final a in ranked.take(5))
        WrappedTrackEntry(
          trackId: a.meta.id,
          title: a.meta.title,
          artistName: a.meta.artistName,
          albumTitle: a.meta.albumTitle,
          coverUrl: a.meta.coverUrl,
          playCount: a.plays,
          totalSeconds: a.seconds,
        ),
    ];

    final artists = <String, _ArtistAgg>{};
    for (final a in ranked) {
      final name = a.meta.artistName;
      if (name.isEmpty) continue;
      final agg = artists.putIfAbsent(name, () => _ArtistAgg(name));
      agg.playCount += a.plays;
      agg.totalSeconds += a.seconds;
      // ranked is sorted, so the first cover seen is the most played track's.
      agg.cover ??= a.meta.coverUrl;
    }
    final topArtists = (artists.values.toList()
          ..sort((a, b) {
            final c = b.playCount.compareTo(a.playCount);
            return c != 0 ? c : b.totalSeconds.compareTo(a.totalSeconds);
          }))
        .take(5)
        .map((a) => WrappedArtistEntry(
              name: a.name,
              playCount: a.playCount,
              totalSeconds: a.totalSeconds,
              coverUrl: a.cover,
            ))
        .toList();

    final facts = <WrappedFunFact>[];
    final marathon = days.reduce((a, b) => a.totalPlays >= b.totalPlays ? a : b);
    facts.add(WrappedFunFact(
      key: 'marathon_day',
      data: {'date': marathon.date, 'count': marathon.totalPlays},
    ));
    _addLoyalArtist(topArtists, facts);
    _addDawnListener(hourDist, facts);
    if (ranked.first.plays >= 10) {
      facts.add(WrappedFunFact(key: 'one_hit_wonder', data: {
        'title': ranked.first.meta.title,
        'artistName': ranked.first.meta.artistName,
        'count': ranked.first.plays,
      }));
    }
    _addShareOfHours(hourDist, totalPlays, facts);
    var weekend = 0, weekday = 0;
    for (final d in days) {
      final wd = d.day.weekday;
      if (wd == DateTime.saturday || wd == DateTime.sunday) {
        weekend += d.totalPlays;
      } else {
        weekday += d.totalPlays;
      }
    }
    _addWeekendWarrior(weekend, weekday, facts);

    return WrappedData(
      year: year,
      topTracks: topTracks,
      topArtists: topArtists,
      totalMinutesListened: totalSeconds ~/ 60,
      totalTracksPlayed: totalPlays,
      uniqueTracksCount: tracks.length,
      uniqueArtistsCount: artists.length,
      favoriteHour: _findFavoriteHour(hourDist),
      hourDistribution: hourDist,
      funFacts: facts,
      generatedAt: DateTime.now(),
      basedOnPlays: true,
      playsSince: days.first.day,
    );
  }

  // ---------------------------------------------------------------------------
  // From first listens only: "what you discovered", never fake play counts
  // ---------------------------------------------------------------------------

  WrappedData generateFromDiscoveries(List<ListenedTrackData> tracks, int year,
      {int? month}) {
    final yearTracks = tracks
        .where((t) =>
            t.listenedAt != null &&
            t.listenedAt!.year == year &&
            (month == null || t.listenedAt!.month == month))
        .toList()
      ..sort((a, b) => a.listenedAt!.compareTo(b.listenedAt!));
    if (yearTracks.isEmpty) return _empty(year);

    // playCount here means "songs discovered" (each song appears once).
    final artists = <String, _ArtistAgg>{};
    final firstTrackOf = <String, ListenedTrackData>{};
    for (final t in yearTracks) {
      final agg = artists.putIfAbsent(t.artistName, () => _ArtistAgg(t.artistName));
      agg.playCount++;
      agg.totalSeconds += t.duration;
      agg.cover ??= t.coverUrl;
      firstTrackOf.putIfAbsent(t.artistName, () => t);
    }
    final topArtistAggs = artists.values.toList()
      ..sort((a, b) {
        final c = b.playCount.compareTo(a.playCount);
        return c != 0 ? c : b.totalSeconds.compareTo(a.totalSeconds);
      });
    final topArtists = [
      for (final a in topArtistAggs.take(5))
        WrappedArtistEntry(
          name: a.name,
          playCount: a.playCount,
          totalSeconds: a.totalSeconds,
          coverUrl: a.cover,
        ),
    ];

    // Highlights: the first song discovered from each top artist.
    final topTracks = [
      for (final a in topArtists)
        if (firstTrackOf[a.name] case final t?)
          WrappedTrackEntry(
            trackId: t.trackId,
            title: t.title,
            artistName: t.artistName,
            albumTitle: t.albumTitle,
            coverUrl: t.coverUrl,
            playCount: 1,
            totalSeconds: t.duration,
          ),
    ];

    final hourDist = <int, int>{};
    for (final t in yearTracks) {
      hourDist.update(t.listenedAt!.hour, (v) => v + 1, ifAbsent: () => 1);
    }

    final facts = <WrappedFunFact>[];
    _addLateNightSong(yearTracks, facts);
    _addMarathonDay(yearTracks, facts);
    _addLoyalArtist(topArtists, facts);
    _addDawnListener(hourDist, facts);
    _addShareOfHours(hourDist, yearTracks.length, facts);
    var weekend = 0, weekday = 0;
    for (final t in yearTracks) {
      final wd = t.listenedAt!.weekday;
      if (wd == DateTime.saturday || wd == DateTime.sunday) {
        weekend++;
      } else {
        weekday++;
      }
    }
    _addWeekendWarrior(weekend, weekday, facts);

    return WrappedData(
      year: year,
      topTracks: topTracks,
      topArtists: topArtists,
      totalMinutesListened:
          yearTracks.fold<int>(0, (s, t) => s + t.duration) ~/ 60,
      totalTracksPlayed: yearTracks.length,
      uniqueTracksCount: yearTracks.length,
      uniqueArtistsCount: artists.length,
      favoriteHour: _findFavoriteHour(hourDist),
      hourDistribution: hourDist,
      funFacts: facts,
      generatedAt: DateTime.now(),
      basedOnPlays: false,
      activeDays: {
        for (final t in yearTracks) PlayDay.keyFor(t.listenedAt!)
      }.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Fun facts
  // ---------------------------------------------------------------------------

  int _findFavoriteHour(Map<int, int> hourDist) {
    if (hourDist.isEmpty) return 0;
    return hourDist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _addLateNightSong(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    final lateNight = tracks
        .where((t) => t.listenedAt!.hour >= 1 && t.listenedAt!.hour <= 4)
        .toList();
    if (lateNight.isEmpty) return;
    final best = lateNight.first;
    facts.add(WrappedFunFact(
      key: 'late_night_song',
      data: {'title': best.title, 'artistName': best.artistName, 'hour': 3},
    ));
  }

  void _addMarathonDay(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    final dayCounts = <String, int>{};
    for (final t in tracks) {
      dayCounts.update(PlayDay.keyFor(t.listenedAt!), (v) => v + 1,
          ifAbsent: () => 1);
    }
    if (dayCounts.isEmpty) return;
    final best = dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    facts.add(WrappedFunFact(
      key: 'marathon_day',
      data: {'date': best.key, 'count': best.value},
    ));
  }

  void _addLoyalArtist(
      List<WrappedArtistEntry> topArtists, List<WrappedFunFact> facts) {
    if (topArtists.length < 2) return;
    if (topArtists[0].playCount >= topArtists[1].playCount * 2) {
      facts.add(WrappedFunFact(
        key: 'loyal_artist',
        data: {'name': topArtists[0].name, 'count': topArtists[0].playCount},
      ));
    }
  }

  void _addDawnListener(Map<int, int> hourDist, List<WrappedFunFact> facts) {
    final dawnCount = [5, 6, 7].fold<int>(0, (s, h) => s + (hourDist[h] ?? 0));
    if (dawnCount > 5) {
      facts.add(WrappedFunFact(key: 'dawn_listener', data: {'count': dawnCount}));
    }
  }

  void _addShareOfHours(
      Map<int, int> hourDist, int total, List<WrappedFunFact> facts) {
    if (total <= 0) return;
    int share(List<int> hours) =>
        (hours.fold<int>(0, (s, h) => s + (hourDist[h] ?? 0)) / total * 100)
            .round();
    final night = share([22, 23, 0, 1, 2, 3, 4]);
    if (night > 30) {
      facts.add(WrappedFunFact(key: 'night_owl', data: {'percentage': night}));
    }
    final morning = share([5, 6, 7, 8, 9]);
    if (morning > 30) {
      facts.add(WrappedFunFact(key: 'early_bird', data: {'percentage': morning}));
    }
  }

  void _addWeekendWarrior(int weekend, int weekday, List<WrappedFunFact> facts) {
    final weekendAvg = weekend / 2.0;
    final weekdayAvg = weekday / 5.0;
    if (weekdayAvg > 0 && weekendAvg > weekdayAvg * 1.5) {
      facts.add(WrappedFunFact(
        key: 'weekend_warrior',
        data: {
          'weekendAvg': weekendAvg.round(),
          'weekdayAvg': weekdayAvg.round(),
        },
      ));
    }
  }
}

class _PlayAgg {
  PlayDayTrack meta;
  int plays = 0;
  int seconds = 0;
  _PlayAgg(this.meta);
}

class _ArtistAgg {
  final String name;
  int playCount = 0;
  int totalSeconds = 0;
  String? cover;
  _ArtistAgg(this.name);
}
