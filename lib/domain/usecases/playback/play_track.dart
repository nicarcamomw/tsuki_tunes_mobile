import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// Plays a song; with [queue], that list becomes the queue (an album,
/// playlist or search results) and the song plays from its place in it.
@injectable
class PlayTrack {
  const PlayTrack(this._player);

  final PlaybackController _player;

  Future<void> call(Track track, {List<Track>? queue}) =>
      _player.playTrack(track, newQueue: queue);
}
