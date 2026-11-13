import '../entities/track.dart';

/// Where playback comes back to when the app starts: the saved queue, the
/// song and the position in it, and the radio when it was on.
class PlaybackRestorePlan {
  final List<Track> queue;
  final int index;
  final Duration position;

  /// The saved song would have ended while the app was closed (it was
  /// playing and enough time passed), so [index] is the song after it, from
  /// its start. The radio isn't brought back then.
  final bool advanced;

  /// The radio's saved state, when it was on.
  final Map<String, dynamic>? radio;

  const PlaybackRestorePlan({
    required this.queue,
    required this.index,
    required this.position,
    this.advanced = false,
    this.radio,
  });

  Track get track => queue[index];
}

/// Reads the playback state saved by the app (StorageService.savePlaybackState)
/// at [now]. Null when there's nothing usable to bring back. Anything
/// missing or malformed falls back to safe values: the first song, the start.
PlaybackRestorePlan? planPlaybackRestore(Map<String, dynamic> state, DateTime now) {
  final rawQueue = state['queue'];
  if (rawQueue is! List || rawQueue.isEmpty) return null;
  final queue = <Track>[
    for (final item in rawQueue)
      if (item is Map) Track.fromJson(Map<String, dynamic>.from(item)),
  ];
  if (queue.isEmpty) return null;

  final rawIndex = state['currentIndex'];
  var index = rawIndex is num ? rawIndex.toInt() : 0;
  if (index < 0 || index >= queue.length) index = 0;
  final rawPosMs = state['position'];
  final posMs = rawPosMs is num ? rawPosMs.toInt() : 0;
  final wasPlaying = state['wasPlaying'] as bool? ?? false;
  final savedAtMs = state['savedAt'] as int?;

  // Killed while playing: if enough wall-clock time has passed for the song
  // to have ended, come back on the next one instead.
  if (wasPlaying && savedAtMs != null && queue.length > 1) {
    final elapsed = now.difference(DateTime.fromMillisecondsSinceEpoch(savedAtMs));
    final song = queue[index];
    final length = Duration(seconds: song.durationSeconds > 0 ? song.durationSeconds : 30);
    if (Duration(milliseconds: posMs) + elapsed >= length) {
      return PlaybackRestorePlan(
        queue: queue,
        index: (index + 1) % queue.length,
        position: Duration.zero,
        advanced: true,
      );
    }
  }

  final rawRadio = state['radio'];
  return PlaybackRestorePlan(
    queue: queue,
    index: index,
    position: Duration(milliseconds: posMs),
    radio: rawRadio is Map ? Map<String, dynamic>.from(rawRadio) : null,
  );
}
