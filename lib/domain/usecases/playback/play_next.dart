import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// Puts a song right after the one playing.
@injectable
class PlayNext {
  const PlayNext(this._player);

  final PlaybackController _player;

  void call(Track track) => _player.playNext(track);
}
