import 'dart:math';

import '../logic/music_styles.dart';

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

  /// Songs of one music style ([WeeklyChallenge.style]): the week's theme,
  /// set by the mask it gives.
  style,
}

class WeeklyChallenge {
  final ChallengeKind kind;
  final int target;

  /// For [ChallengeKind.style] challenges.
  final MusicStyle? style;

  const WeeklyChallenge(this.kind, this.target, {this.style});

  /// The themed challenge: [target] songs of [style].
  const WeeklyChallenge.ofStyle(MusicStyle this.style, {this.target = 15}) : kind = ChallengeKind.style;

  @override
  bool operator ==(Object other) =>
      other is WeeklyChallenge && other.kind == kind && other.target == target && other.style == style;

  @override
  int get hashCode => Object.hash(kind, target, style);

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
