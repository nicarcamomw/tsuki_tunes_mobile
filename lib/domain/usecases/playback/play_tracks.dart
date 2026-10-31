import 'dart:math';

import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// "Play" and "Shuffle" on a list of songs: it becomes the queue and plays
/// from the first song (of the shuffled order when [shuffled]). Returns
/// false for an empty list, which plays nothing.
class PlayTracks {
  PlayTracks(this._player, {Random? random}) : _random = random ?? Random();

  final PlaybackController _player;
  final Random _random;

  Future<bool> call(List<Track> tracks, {bool shuffled = false}) async {
    if (tracks.isEmpty) return false;
    final queue = shuffled ? (List.of(tracks)..shuffle(_random)) : tracks;
    await _player.playTrack(queue.first, newQueue: queue);
    return true;
  }
}
