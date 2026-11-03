class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

class SyncedLyrics {
  final bool isInstrumental;
  final bool isSynced;
  final List<LyricLine> lines;
  final String plainLyrics;

  /// When instrumental breaks start: timestamps with no words, which end
  /// the line before them (see [inBreakAt]).
  final List<Duration> breaks;

  const SyncedLyrics({
    this.isInstrumental = false,
    this.isSynced = false,
    this.lines = const [],
    this.plainLyrics = '',
    this.breaks = const [],
  });

  static const empty = SyncedLyrics();

  static final _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final _offsetTag = RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]$', caseSensitive: false);

  /// Parses an LRC file into timed lines.
  ///
  /// - A line may carry several timestamps (a chorus written once,
  ///   `[00:12.00][01:05.30]text`): it's placed at each.
  /// - A timestamp with no words marks an instrumental break.
  /// - `[offset:+300]` (milliseconds) moves every line that much earlier,
  ///   as the format says; negative values move them later.
  factory SyncedLyrics.fromLrc(String lrc) {
    if (lrc.trim().isEmpty) return SyncedLyrics.empty;

    var offset = Duration.zero;
    final parsed = <LyricLine>[];
    final breaks = <Duration>[];

    for (final raw in lrc.split('\n')) {
      final line = raw.trim();
      final tag = _offsetTag.firstMatch(line);
      if (tag != null) {
        offset = Duration(milliseconds: int.parse(tag.group(1)!));
        continue;
      }
      // The timestamps at the start, then the words.
      final times = <Duration>[];
      var rest = line;
      while (true) {
        final m = _stamp.matchAsPrefix(rest);
        if (m == null) break;
        final fraction = m.group(3) ?? '0';
        final ms = switch (fraction.length) {
          1 => int.parse(fraction) * 100,
          2 => int.parse(fraction) * 10,
          _ => int.parse(fraction),
        };
        times.add(Duration(
          minutes: int.parse(m.group(1)!),
          seconds: int.parse(m.group(2)!),
          milliseconds: ms,
        ));
        rest = rest.substring(m.end).trimLeft();
      }
      if (times.isEmpty) continue;
      final text = rest.trim();
      for (final t in times) {
        if (text.isEmpty) {
          breaks.add(t);
        } else {
          parsed.add(LyricLine(time: t, text: text));
        }
      }
    }

    Duration shift(Duration t) {
      final moved = t - offset;
      return moved < Duration.zero ? Duration.zero : moved;
    }

    final lines = [
      for (final l in parsed) LyricLine(time: shift(l.time), text: l.text),
    ]..sort((a, b) => a.time.compareTo(b.time));
    final pauses = [for (final b in breaks) shift(b)]..sort();
    // A break at the very start (before any words) changes nothing.
    final firstLine = lines.isEmpty ? Duration.zero : lines.first.time;
    pauses.removeWhere((b) => b <= firstLine);

    return SyncedLyrics(
      isSynced: lines.isNotEmpty,
      lines: lines,
      plainLyrics: lines.map((l) => l.text).join('\n'),
      breaks: pauses,
    );
  }

  /// Finds the index of the line currently active at [position].
  /// [leadOffset] provides an anticipation window (default 320ms) so the
  /// lyric line highlights and begins scrolling slightly ahead of the vocal onset,
  /// compensating for Bluetooth/DAC latency and matching natural reading pace.
  int activeIndexAt(
    Duration position, {
    Duration leadOffset = const Duration(milliseconds: 320),
  }) {
    if (lines.isEmpty) return -1;
    final targetTime = position + leadOffset;
    int activeIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (targetTime >= lines[i].time) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }

  /// Whether [position] falls in an instrumental break: the last line was
  /// sung and the next hasn't started, so no line should look current.
  bool inBreakAt(
    Duration position, {
    Duration leadOffset = const Duration(milliseconds: 320),
  }) {
    if (breaks.isEmpty) return false;
    final t = position + leadOffset;
    final i = activeIndexAt(position, leadOffset: leadOffset);
    if (i < 0) return false;
    final lineAt = lines[i].time;
    return breaks.any((b) => b > lineAt && b <= t);
  }
}
