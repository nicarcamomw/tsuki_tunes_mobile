import 'track.dart';

/// Listening together: a host plays, their Bonds who joined hear the same
/// song at the same point. The host's player is the clock: [positionMs] at
/// [at], moving on while [playing].
class Party {
  const Party({
    required this.host,
    required this.hostName,
    required this.members,
    required this.invited,
    required this.names,
    this.track,
    this.positionMs = 0,
    this.playing = false,
    this.at,
  });

  /// The host's uid (the party's id: one party per host).
  final String host;
  final String hostName;
  final List<String> members;
  final List<String> invited;
  final Map<String, String> names;
  final Track? track;
  final int positionMs;
  final bool playing;
  final DateTime? at;

  static const maxMembers = 10;

  String nameOf(String uid) => uid == host ? hostName : names[uid] ?? '?';

  /// Where the host is now, by their clock.
  Duration positionAt(DateTime now) {
    final base = Duration(milliseconds: positionMs);
    final since = at;
    if (!playing || since == null) return base;
    final elapsed = now.difference(since);
    return elapsed.isNegative ? base : base + elapsed;
  }
}
