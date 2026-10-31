import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// Adds songs to the end of the queue.
class AddToQueue {
  const AddToQueue(this._player);

  final PlaybackController _player;

  void call(Track track) => _player.addToQueue(track);

  void all(List<Track> tracks) => _player.addAllToQueue(tracks);
}
