import 'package:injectable/injectable.dart';

import '../../entities/track.dart';
import '../../repositories/playback_controller.dart';

/// Starts an endless radio of songs like [seed]. False if it found none.
@injectable
class StartRadio {
  const StartRadio(this._player);

  final PlaybackController _player;

  Future<bool> call(Track seed) => _player.startRadio(seed);
}
