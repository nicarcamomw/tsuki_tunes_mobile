import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'contracts/audio_player_contract.dart';

class AudioPlayerService implements AudioPlayerContract {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;

  Future<void> playTrack(Track track) async {
    if (track.previewUrl.isEmpty) {
      throw Exception('Audio preview is unavailable for this track');
    }

    try {
      await _player.stop();
      await _player.setUrl(track.previewUrl);
      await _player.play();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resume() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> stop() async => await _player.stop();
  Future<void> seek(Duration position) async => await _player.seek(position);

  Future<void> setVolume(double volume) async => await _player.setVolume(volume);

  Future<void> dispose() async {
    await _player.dispose();
  }
}
