import 'dart:math';

/// What a weekly challenge counts.
enum ChallengeKind {
  /// Artists heard for the first time.
  newArtists,

  /// Minutes of music.
  minutes,

  /// Songs listened to (counted plays).
  plays,

  /// Different days with music.
  days,

  /// Songs after midnight (0:00–4:59).
  night,

  /// Songs early in the morning (5:00–8:59).
  morning,

  /// Minutes of rain or storm ambience.
  rain,

  /// Albums listened to in order, 5+ songs in a row.
  album,

  /// Daily "guess the song" challenges won.
  guess,

  /// Songs by one same artist.
  oneArtist,
}

class WeeklyChallenge {
  final ChallengeKind kind;
  final int target;

  const WeeklyChallenge(this.kind, this.target);

  static const pool = [
    WeeklyChallenge(ChallengeKind.newArtists, 3),
    WeeklyChallenge(ChallengeKind.minutes, 90),
    WeeklyChallenge(ChallengeKind.plays, 40),
    WeeklyChallenge(ChallengeKind.days, 4),
    WeeklyChallenge(ChallengeKind.night, 3),
    WeeklyChallenge(ChallengeKind.morning, 5),
    WeeklyChallenge(ChallengeKind.rain, 30),
    WeeklyChallenge(ChallengeKind.album, 1),
    WeeklyChallenge(ChallengeKind.guess, 3),
    WeeklyChallenge(ChallengeKind.oneArtist, 15),
  ];

  /// Weeks since Monday 1 January 2024, the week of [t] (Monday to Sunday,
  /// local dates).
  static int weekOf(DateTime t) {
    final day = DateTime.utc(t.year, t.month, t.day);
    return day.difference(DateTime.utc(2024, 1, 1)).inDays ~/ 7;
  }

  /// The Monday that starts [week].
  static DateTime mondayOf(int week) =>
      DateTime.utc(2024, 1, 1).add(Duration(days: week * 7));

  /// The week's three challenges: the same for everyone, new each Monday,
  /// never two about the time of day at once.
  static List<WeeklyChallenge> forWeek(int week) {
    final picks = List.of(pool)..shuffle(Random(week * 7919 + 13));
    final out = <WeeklyChallenge>[];
    const timeOfDay = {ChallengeKind.night, ChallengeKind.morning};
    for (final c in picks) {
      if (timeOfDay.contains(c.kind) && out.any((o) => timeOfDay.contains(o.kind))) continue;
      out.add(c);
      if (out.length == 3) break;
    }
    return out;
  }
}
