import 'package:just_audio/just_audio.dart';
import '../../models/track.dart';

abstract class AudioPlayerContract {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<PlayerState> get playerStateStream;
  Stream<bool> get playingStream;

  Future<void> playTrack(Track track);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
