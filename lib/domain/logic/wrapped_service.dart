import '../entities/album.dart';
import '../entities/listened_track.dart';
import '../entities/play_day.dart';
import '../entities/wrapped_data.dart';

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
    // Whole days in UTC: a daylight-saving change makes a local day 23 or 25
    // hours long, which would drop or add one.
    final start = DateTime.utc(year, month ?? 1, 1);
    final end = month == null ? DateTime.utc(year + 1, 1, 1) : DateTime.utc(year, month + 1, 1);
    final today = DateTime.utc(now.year, now.month, now.day + 1);
    final until = today.isBefore(end) ? today : end;
    final total = until.isAfter(start) ? until.difference(start).inDays : 0;
    final active = data.basedOnPlays
        ? days.where((d) => d.totalPlays > 0).length
        : data.activeDays;
    final streak = data.basedOnPlays
        ? longestStreak([for (final d in days) if (d.totalPlays > 0) d.date])
        : (data.longestStreak, data.streakStart);
    return data.copyWith(
      year: year,
      month: month,
      activeDays: active,
      periodDays: total,
      longestStreak: streak.$1,
      streakStart: streak.$2,
    );
  }

  /// The most days in a row among [dates] ('yyyy-MM-dd'), and the first of
  /// them; (0, null) when there are none.
  static (int, DateTime?) longestStreak(Iterable<String> dates) {
    final sorted = {
      for (final d in dates)
        if (DateTime.tryParse(d) case final t?) DateTime.utc(t.year, t.month, t.day),
    }.toList()
      ..sort();
    if (sorted.isEmpty) return (0, null);
    var best = 1, run = 1;
    var bestStart = sorted.first, runStart = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
        runStart = sorted[i];
      }
      if (run > best) {
        best = run;
        bestStart = runStart;
      }
    }
    return (best, DateTime(bestStart.year, bestStart.month, bestStart.day));
  }

  /// Most-played albums: songs grouped by album, ranked by plays. Only
  /// albums with two or more different songs heard count; one song played
  /// many times is a top song, not an album.
  static List<WrappedAlbumEntry> topAlbumsOf(
    Iterable<({String trackId, String albumId, String albumTitle, String artistName, String coverUrl, int plays})> songs, {
    int limit = 5,
  }) {
    final albums = <String, _AlbumAgg>{};
    for (final s in songs) {
      if (s.albumId.isEmpty && s.albumTitle.isEmpty) continue;
      final key = s.albumId.isNotEmpty ? s.albumId : '${s.albumTitle}|${s.artistName}';
      final agg = albums.putIfAbsent(key, () => _AlbumAgg(s.albumId, s.albumTitle, s.artistName, s.coverUrl));
      agg.plays += s.plays;
      agg.tracks.add(s.trackId);
      if (agg.cover.isEmpty) agg.cover = s.coverUrl;
      if (agg.title.isEmpty) agg.title = s.albumTitle;
    }
    final ranked = albums.values.where((a) => a.tracks.length >= 2 && a.title.isNotEmpty).toList()
      ..sort((a, b) {
        final c = b.plays.compareTo(a.plays);
        return c != 0 ? c : b.tracks.length.compareTo(a.tracks.length);
      });
    return [
      for (final a in ranked.take(limit))
        WrappedAlbumEntry(
          albumId: a.id,
          title: a.title,
          artistName: a.artist,
          coverUrl: a.cover,
          playCount: a.plays,
          trackIds: a.tracks.toList(),
        ),
    ];
  }

  /// [data] with the albums heard whole: the catalog says how many songs
  /// each has. Like the "kanpeki" mask, only real albums (not singles or
  /// EPs) of five songs or more. Looks up at most [maxLookups] albums, those
  /// with the most songs heard; any that can't be looked up are skipped.
  Future<WrappedData> withCompletedAlbums(
    WrappedData data,
    Future<Album?> Function(String albumId) lookup, {
    int maxLookups = 8,
  }) async {
    final candidates = data.topAlbums.where((a) => a.albumId.isNotEmpty && a.tracksHeard >= 5).toList()
      ..sort((a, b) => b.tracksHeard.compareTo(a.tracksHeard));
    final completed = <WrappedAlbumEntry>[];
    for (final a in candidates.take(maxLookups)) {
      final Album? album;
      try {
        album = await lookup(a.albumId);
      } catch (_) {
        continue;
      }
      if (album == null || album.recordType != 'album' || album.tracksCount < 5) continue;
      final heard = a.trackIds.toSet();
      // The tracklist when the catalog gave it (same songs, not just as
      // many), else the count.
      final whole = album.tracks.isNotEmpty
          ? album.tracks.every((t) => heard.contains(t.id)) && heard.length >= album.tracksCount
          : heard.length >= album.tracksCount;
      if (whole) completed.add(a.copyWith(totalTracks: album.tracksCount));
    }
    return data.copyWith(completedAlbums: completed);
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

    final topAlbums = topAlbumsOf([
      for (final a in ranked)
        (
          trackId: a.meta.id,
          albumId: a.meta.albumId,
          albumTitle: a.meta.albumTitle,
          artistName: a.meta.artistName,
          coverUrl: a.meta.coverUrl,
          plays: a.plays,
        ),
    ], limit: 20);

    return WrappedData(
      year: year,
      topTracks: topTracks,
      topArtists: topArtists,
      topAlbums: topAlbums,
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

    final dayKeys = {for (final t in yearTracks) PlayDay.keyFor(t.listenedAt!)};
    final streak = longestStreak(dayKeys);
    final topAlbums = topAlbumsOf([
      for (final t in yearTracks)
        (
          trackId: t.trackId,
          albumId: t.albumId,
          albumTitle: t.albumTitle,
          artistName: t.artistName,
          coverUrl: t.coverUrl,
          plays: 1,
        ),
    ], limit: 20);

    return WrappedData(
      year: year,
      topTracks: topTracks,
      topArtists: topArtists,
      topAlbums: topAlbums,
      longestStreak: streak.$1,
      streakStart: streak.$2,
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
      activeDays: dayKeys.length,
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

class _AlbumAgg {
  final String id;
  String title;
  final String artist;
  String cover;
  int plays = 0;
  final Set<String> tracks = {};
  _AlbumAgg(this.id, this.title, this.artist, this.cover);
}
