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

  const SyncedLyrics({
    this.isInstrumental = false,
    this.isSynced = false,
    this.lines = const [],
    this.plainLyrics = '',
  });

  static const empty = SyncedLyrics();

  /// Parses standard LRC string into structured timed lines.
  factory SyncedLyrics.fromLrc(String lrc) {
    if (lrc.trim().isEmpty) return SyncedLyrics.empty;

    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final List<LyricLine> parsedLines = [];

    for (final rawLine in lrc.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final rawMs = match.group(3) ?? '0';
        final ms = rawMs.length == 2
            ? (int.tryParse(rawMs) ?? 0) * 10
            : (int.tryParse(rawMs) ?? 0);
        final text = match.group(4)?.trim() ?? '';

        if (text.isNotEmpty) {
          parsedLines.add(LyricLine(
            time: Duration(
                minutes: minutes, seconds: seconds, milliseconds: ms),
            text: text,
          ));
        }
      }
    }

    parsedLines.sort((a, b) => a.time.compareTo(b.time));

    return SyncedLyrics(
      isSynced: parsedLines.isNotEmpty,
      lines: parsedLines,
      plainLyrics: parsedLines.map((l) => l.text).join('\n'),
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
}
