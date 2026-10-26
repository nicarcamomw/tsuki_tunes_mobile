import '../models/wrapped_data.dart';
import '../providers/library_provider.dart';

class WrappedService {
  static final WrappedService _instance = WrappedService._internal();
  factory WrappedService() => _instance;
  WrappedService._internal();

  WrappedData generateWrapped(List<ListenedTrackData> tracks, int year) {
    final yearTracks = tracks
        .where((t) => t.listenedAt != null && t.listenedAt!.year == year)
        .toList();

    if (yearTracks.isEmpty) {
      return WrappedData(
        year: year,
        topTracks: [],
        topArtists: [],
        totalMinutesListened: 0,
        totalTracksPlayed: 0,
        uniqueTracksCount: 0,
        uniqueArtistsCount: 0,
        favoriteHour: 0,
        hourDistribution: {},
        funFacts: [],
        generatedAt: DateTime.now(),
      );
    }

    final topTracks = _buildTopTracks(yearTracks);
    final topArtists = _buildTopArtists(yearTracks);
    final hourDist = _buildHourDistribution(yearTracks);
    final favHour = _findFavoriteHour(hourDist);
    final totalSeconds =
        yearTracks.fold<int>(0, (sum, t) => sum + t.duration);
    final uniqueTracks = yearTracks.map((t) => t.trackId).toSet();
    final uniqueArtists = yearTracks.map((t) => t.artistName).toSet();
    final funFacts = _generateFunFacts(yearTracks, topArtists, hourDist);

    return WrappedData(
      year: year,
      topTracks: topTracks,
      topArtists: topArtists,
      totalMinutesListened: totalSeconds ~/ 60,
      totalTracksPlayed: yearTracks.length,
      uniqueTracksCount: uniqueTracks.length,
      uniqueArtistsCount: uniqueArtists.length,
      favoriteHour: favHour,
      hourDistribution: hourDist,
      funFacts: funFacts,
      generatedAt: DateTime.now(),
    );
  }

  List<WrappedTrackEntry> _buildTopTracks(List<ListenedTrackData> tracks) {
    final Map<String, _TrackAgg> agg = {};
    for (final t in tracks) {
      final a = agg.putIfAbsent(t.trackId, () => _TrackAgg(t));
      a.playCount++;
      a.totalSeconds += t.duration;
    }

    final sorted = agg.values.toList()
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        return cmp != 0 ? cmp : b.totalSeconds.compareTo(a.totalSeconds);
      });

    return sorted.take(5).map((a) => WrappedTrackEntry(
          trackId: a.track.trackId,
          title: a.track.title,
          artistName: a.track.artistName,
          albumTitle: a.track.albumTitle,
          coverUrl: a.track.coverUrl,
          playCount: a.playCount,
          totalSeconds: a.totalSeconds,
        )).toList();
  }

  List<WrappedArtistEntry> _buildTopArtists(List<ListenedTrackData> tracks) {
    final Map<String, _ArtistAgg> agg = {};
    for (final t in tracks) {
      final a = agg.putIfAbsent(
          t.artistName, () => _ArtistAgg(t.artistName));
      a.playCount++;
      a.totalSeconds += t.duration;
      a.trackPlays.update(t.trackId, (v) => v + 1, ifAbsent: () => 1);
      a.trackCovers[t.trackId] = t.coverUrl;
    }

    final sorted = agg.values.toList()
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        return cmp != 0 ? cmp : b.totalSeconds.compareTo(a.totalSeconds);
      });

    return sorted.take(5).map((a) {
      String? bestCover;
      if (a.trackPlays.isNotEmpty) {
        final bestTrackId = a.trackPlays.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
        bestCover = a.trackCovers[bestTrackId];
      }
      return WrappedArtistEntry(
        name: a.name,
        playCount: a.playCount,
        totalSeconds: a.totalSeconds,
        coverUrl: bestCover,
      );
    }).toList();
  }

  Map<int, int> _buildHourDistribution(List<ListenedTrackData> tracks) {
    final Map<int, int> dist = {};
    for (final t in tracks) {
      final hour = t.listenedAt!.hour;
      dist.update(hour, (v) => v + 1, ifAbsent: () => 1);
    }
    return dist;
  }

  int _findFavoriteHour(Map<int, int> hourDist) {
    if (hourDist.isEmpty) return 0;
    return hourDist.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  List<WrappedFunFact> _generateFunFacts(
    List<ListenedTrackData> tracks,
    List<WrappedArtistEntry> topArtists,
    Map<int, int> hourDist,
  ) {
    final facts = <WrappedFunFact>[];

    _addLateNightSong(tracks, facts);
    _addMarathonDay(tracks, facts);
    _addLoyalArtist(topArtists, facts);
    _addDawnListener(hourDist, facts);
    _addOneHitWonder(tracks, facts);
    _addNightOwl(tracks, hourDist, facts);
    _addEarlyBird(tracks, hourDist, facts);
    _addWeekendWarrior(tracks, facts);

    return facts;
  }

  void _addLateNightSong(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    final lateNight =
        tracks.where((t) => t.listenedAt!.hour >= 1 && t.listenedAt!.hour <= 4);
    if (lateNight.isEmpty) return;

    final Map<String, int> counts = {};
    final Map<String, ListenedTrackData> refs = {};
    for (final t in lateNight) {
      counts.update(t.trackId, (v) => v + 1, ifAbsent: () => 1);
      refs.putIfAbsent(t.trackId, () => t);
    }

    final bestId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final best = refs[bestId]!;
    facts.add(WrappedFunFact(
      key: 'late_night_song',
      data: {
        'title': best.title,
        'artistName': best.artistName,
        'hour': 3,
      },
    ));
  }

  void _addMarathonDay(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    final Map<String, int> dayCounts = {};
    for (final t in tracks) {
      final day =
          '${t.listenedAt!.year}-${t.listenedAt!.month.toString().padLeft(2, '0')}-${t.listenedAt!.day.toString().padLeft(2, '0')}';
      dayCounts.update(day, (v) => v + 1, ifAbsent: () => 1);
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

  void _addDawnListener(
      Map<int, int> hourDist, List<WrappedFunFact> facts) {
    final dawnCount = [5, 6, 7].fold<int>(0, (s, h) => s + (hourDist[h] ?? 0));
    if (dawnCount > 5) {
      facts.add(WrappedFunFact(
        key: 'dawn_listener',
        data: {'count': dawnCount},
      ));
    }
  }

  void _addOneHitWonder(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    final Map<String, int> counts = {};
    final Map<String, ListenedTrackData> refs = {};
    for (final t in tracks) {
      counts.update(t.trackId, (v) => v + 1, ifAbsent: () => 1);
      refs.putIfAbsent(t.trackId, () => t);
    }
    if (counts.isEmpty) return;

    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value >= 10) {
      final t = refs[best.key]!;
      facts.add(WrappedFunFact(
        key: 'one_hit_wonder',
        data: {'title': t.title, 'artistName': t.artistName, 'count': best.value},
      ));
    }
  }

  void _addNightOwl(List<ListenedTrackData> tracks, Map<int, int> hourDist,
      List<WrappedFunFact> facts) {
    if (tracks.isEmpty) return;
    final nightHours = [22, 23, 0, 1, 2, 3, 4];
    final nightCount =
        nightHours.fold<int>(0, (s, h) => s + (hourDist[h] ?? 0));
    final pct = (nightCount / tracks.length * 100).round();
    if (pct > 30) {
      facts.add(WrappedFunFact(
        key: 'night_owl',
        data: {'percentage': pct},
      ));
    }
  }

  void _addEarlyBird(List<ListenedTrackData> tracks, Map<int, int> hourDist,
      List<WrappedFunFact> facts) {
    if (tracks.isEmpty) return;
    final morningHours = [5, 6, 7, 8, 9];
    final morningCount =
        morningHours.fold<int>(0, (s, h) => s + (hourDist[h] ?? 0));
    final pct = (morningCount / tracks.length * 100).round();
    if (pct > 30) {
      facts.add(WrappedFunFact(
        key: 'early_bird',
        data: {'percentage': pct},
      ));
    }
  }

  void _addWeekendWarrior(
      List<ListenedTrackData> tracks, List<WrappedFunFact> facts) {
    if (tracks.isEmpty) return;
    int weekendCount = 0;
    int weekdayCount = 0;
    for (final t in tracks) {
      final wd = t.listenedAt!.weekday;
      if (wd == DateTime.saturday || wd == DateTime.sunday) {
        weekendCount++;
      } else {
        weekdayCount++;
      }
    }

    final weekendAvg = weekendCount / 2.0;
    final weekdayAvg = weekdayCount / 5.0;
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

class _TrackAgg {
  final ListenedTrackData track;
  int playCount = 0;
  int totalSeconds = 0;
  _TrackAgg(this.track);
}

class _ArtistAgg {
  final String name;
  int playCount = 0;
  int totalSeconds = 0;
  final Map<String, int> trackPlays = {};
  final Map<String, String> trackCovers = {};
  _ArtistAgg(this.name);
}
