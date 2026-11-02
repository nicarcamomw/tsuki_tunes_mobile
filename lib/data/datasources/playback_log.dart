import 'dart:collection';

/// The last few hundred playback events (Spotify commands and answers, the
/// player's state changes), with their time, kept in memory only. The user
/// can copy them from settings to show what happened when playback went
/// wrong on their phone, which can't be seen from anywhere else. Nothing is
/// written to the system log or sent anywhere.
class PlaybackLog {
  PlaybackLog._();
  static final PlaybackLog instance = PlaybackLog._();

  static const int maxLines = 400;

  // What playback logs through debugPrint carries one of these.
  static const _markers = ['[AudioProvider]', 'Spotify', '[SpotifyCheck]', 'AudioPlayerService', '[Lyrics', '[FeatureFlags]'];

  final Queue<String> _lines = Queue();

  /// Keeps [message] when it's a playback event.
  void capture(String? message) {
    if (message == null || !_markers.any(message.contains)) return;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    _lines.addLast('$stamp $message');
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
  }

  int get length => _lines.length;

  /// Everything kept, oldest first, one event per line.
  String dump() => _lines.join('\n');

  void clear() => _lines.clear();
}
