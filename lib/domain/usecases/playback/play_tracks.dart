import 'dart:math';

import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// "Play" and "Shuffle" on a list of songs: it becomes the queue and plays
/// from its first song, or, when [shuffled], from a random one with the
/// player's shuffle on (so what follows is shuffle's: every song once,
/// artists spread out, and the shuffle button shows it). Returns false for
/// an empty list, which plays nothing.
@injectable
class PlayTracks {
  PlayTracks(this._player, {@ignoreParam Random? random}) : _random = random ?? Random();

  final PlaybackController _player;
  final Random _random;

  Future<bool> call(List<Track> tracks, {bool shuffled = false}) async {
    if (tracks.isEmpty) return false;
    if (shuffled) {
      await _player.playShuffled(tracks[_random.nextInt(tracks.length)], tracks);
    } else {
      await _player.playTrack(tracks.first, newQueue: tracks);
    }
    return true;
  }
}
