import 'package:injectable/injectable.dart';

import '../../entities/artist.dart';
import '../../repositories/playback_controller.dart';

/// Starts an endless radio of [Artist]: their top songs, then those of
/// artists like them. False if it found none.
@injectable
class StartArtistRadio {
  const StartArtistRadio(this._player);

  final PlaybackController _player;

  Future<bool> call(Artist artist) => _player.startArtistRadio(artist);
}
