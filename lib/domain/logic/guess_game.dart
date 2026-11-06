import 'dart:convert';
import 'dart:math';

import '../entities/track.dart';
import 'artist_names.dart';

enum GuessMode { daily, library, artist, chart }

enum GuessOutcome { skipped, wrong, rightArtist, correct }

class GuessGame {
  /// Seconds of the clip unlocked at each attempt.
  static const List<int> clipSeconds = [1, 2, 4, 7, 11, 16];
  static int get maxAttempts => clipSeconds.length;

  static final DateTime _epoch = DateTime.utc(2026, 10, 26);

  /// Challenge number for the local calendar day, starting at 1. Uses UTC
  /// dates so DST changes don't produce 23 or 25 hour days.
  static int dayNumber(DateTime now) =>
      DateTime.utc(now.year, now.month, now.day).difference(_epoch).inDays + 1;

  static Duration untilNextDay(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1).difference(now);

  /// Today's song from [pool], chosen by highest hash of (day, track id)
  /// rather than by position. The chart reorders through the day and differs
  /// a little between regions; by position any shift changes the song, while
  /// here it only changes if today's winner leaves the pool (or a newcomer
  /// out-hashes it), so phones agree far more often.
  static T dailyPick<T>(int day, List<T> pool, String Function(T) idOf) {
    var best = pool.first;
    var bestScore = -1;
    for (final item in pool) {
      final score = _mix(day, idOf(item));
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return best;
  }

  // FNV-1a over the day and id, then a murmur-style finalizer.
  static int _mix(int day, String id) {
    var h = 0x811C9DC5;
    for (final unit in '$day:$id'.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    h = ((h ^ (h >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
    return h ^ (h >> 16);
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  static final RegExp _brackets = RegExp(r'\([^)]*\)|\[[^\]]*\]');
  static final RegExp _suffix = RegExp(r'\s+-\s+.*$|\s+(feat\.?|ft\.?|featuring)\s.*$');
  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]', unicode: true);

  /// Strips accents, "(Remastered)", " - Live", "feat. X" and punctuation, so
  /// different versions of the same song compare equal. Keeps non-Latin
  /// letters so Japanese or Korean titles still work.
  static String normalize(String s) {
    var out = s.toLowerCase();
    out = out.split('').map((c) => _accents[c] ?? c).join();
    out = out.replaceAll(_brackets, ' ');
    out = out.replaceAll(_suffix, '');
    final stripped = out.replaceAll(_nonWord, '');
    return stripped.isEmpty ? s.toLowerCase().trim() : stripped;
  }

  /// One entry per song: drops later tracks with the same normalized title
  /// and main artist (remasters, live cuts, re-releases), keeping order.
  /// Safe for guesses, since [judge] treats those versions as the same song.
  static List<Track> uniqueSongs(Iterable<Track> tracks) {
    final seen = <String>{};
    return tracks
        .where((t) =>
            seen.add('${normalize(t.title)}|${normalize(ArtistNames.primary(t.artistName))}'))
        .toList();
  }

  static bool _sameArtist(Track a, Track b) {
    if (a.artistId.isNotEmpty && a.artistId == b.artistId) return true;
    final na = normalize(ArtistNames.primary(a.artistName));
    final nb = normalize(ArtistNames.primary(b.artistName));
    return na.isNotEmpty && na == nb;
  }

  static GuessOutcome judge(Track target, Track guess) {
    if (guess.id == target.id) return GuessOutcome.correct;
    final sameArtist = _sameArtist(target, guess);
    if (sameArtist && normalize(guess.title) == normalize(target.title)) {
      return GuessOutcome.correct;
    }
    return sameArtist ? GuessOutcome.rightArtist : GuessOutcome.wrong;
  }

  /// The attempts as plain symbols (no emoji): ● right, ◐ right artist,
  /// ○ wrong, – skipped, · not used.
  static String resultRow(List<GuessOutcome> outcomes) {
    final cells = outcomes.map((o) => switch (o) {
          GuessOutcome.skipped => '–',
          GuessOutcome.wrong => '○',
          GuessOutcome.rightArtist => '◐',
          GuessOutcome.correct => '●',
        });
    final unused = List.filled(max(0, maxAttempts - outcomes.length), '·');
    return [...cells, ...unused].join(' ');
  }

  static bool isWon(List<GuessOutcome> outcomes) =>
      outcomes.isNotEmpty && outcomes.last == GuessOutcome.correct;

  static bool isFinished(List<GuessOutcome> outcomes) =>
      isWon(outcomes) || outcomes.length >= maxAttempts;

  static String shareText({
    required String header,
    required List<GuessOutcome> outcomes,
  }) {
    final score = isWon(outcomes) ? '${outcomes.length}' : 'X';
    return '$header  $score/$maxAttempts\n${resultRow(outcomes)}';
  }
}

/// Daily-challenge statistics, Wordle style.
class GuessStats {
  int played;
  int wins;
  int streak;
  int maxStreak;
  int lastWonDay;
  int lastPlayedDay;
  /// Wins at attempt 1..6, then losses at index 6.
  List<int> distribution;

  GuessStats({
    this.played = 0,
    this.wins = 0,
    this.streak = 0,
    this.maxStreak = 0,
    this.lastWonDay = -1,
    this.lastPlayedDay = -1,
    List<int>? distribution,
  }) : distribution = distribution ?? List.filled(GuessGame.maxAttempts + 1, 0);

  /// Streak to display today: it's already broken if yesterday was missed.
  int currentStreak(int today) =>
      lastWonDay >= today - 1 ? streak : 0;

  int get winRate => played == 0 ? 0 : (wins * 100 / played).round();

  void record(int day, List<GuessOutcome> outcomes) {
    if (lastPlayedDay == day) return;
    lastPlayedDay = day;
    played++;
    if (GuessGame.isWon(outcomes)) {
      wins++;
      streak = lastWonDay == day - 1 ? streak + 1 : 1;
      maxStreak = max(maxStreak, streak);
      lastWonDay = day;
      distribution[outcomes.length - 1]++;
    } else {
      streak = 0;
      distribution[GuessGame.maxAttempts]++;
    }
  }

  String encode() => jsonEncode({
        'played': played,
        'wins': wins,
        'streak': streak,
        'maxStreak': maxStreak,
        'lastWonDay': lastWonDay,
        'lastPlayedDay': lastPlayedDay,
        'distribution': distribution,
      });

  static GuessStats decode(String? raw) {
    if (raw == null) return GuessStats();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final dist = (m['distribution'] as List?)?.map((e) => e as int).toList();
      return GuessStats(
        played: m['played'] ?? 0,
        wins: m['wins'] ?? 0,
        streak: m['streak'] ?? 0,
        maxStreak: m['maxStreak'] ?? 0,
        lastWonDay: m['lastWonDay'] ?? -1,
        lastPlayedDay: m['lastPlayedDay'] ?? -1,
        distribution: dist != null && dist.length == GuessGame.maxAttempts + 1
            ? dist
            : null,
      );
    } catch (_) {
      return GuessStats();
    }
  }
}

/// A round in progress (today's daily one, or the last one of a free mode),
/// so leaving and reopening the game keeps progress.
class DailyRoundState {
  final int day;
  final String trackId;
  final List<GuessOutcome> outcomes;
  final List<String> guessLabels;
  /// What the round belongs to beyond its mode: the artist's id in artist
  /// mode, empty otherwise.
  final String scope;

  DailyRoundState({
    required this.day,
    required this.trackId,
    required this.outcomes,
    required this.guessLabels,
    this.scope = '',
  });

  String encode() => jsonEncode({
        'day': day,
        'trackId': trackId,
        'outcomes': outcomes.map((o) => o.name).toList(),
        'labels': guessLabels,
        if (scope.isNotEmpty) 'scope': scope,
      });

  static DailyRoundState? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return DailyRoundState(
        day: m['day'] as int,
        trackId: m['trackId'] as String,
        outcomes: (m['outcomes'] as List)
            .map((n) => GuessOutcome.values.firstWhere((o) => o.name == n))
            .toList(),
        guessLabels: (m['labels'] as List).map((e) => e as String).toList(),
        scope: m['scope'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
