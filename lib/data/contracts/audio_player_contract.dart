import 'package:just_audio/just_audio.dart';
import '../../domain/entities/track.dart';

abstract class AudioPlayerContract {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<PlayerState> get playerStateStream;
  Stream<bool> get playingStream;
  Stream<PlaybackEvent> get playbackEventStream;

  Future<void> playTrack(Track track, {Duration? initialPosition});
  Future<void> crossfadeTo(Track nextTrack, int durationSeconds);

  /// Gapless: [next] starts the instant the current song ends (null takes
  /// it back). False when it couldn't be queued.
  Future<bool> setGaplessNext(Track? next);
  Track? get gaplessNext;

  /// A song queued with [setGaplessNext] started by itself.
  Stream<Track> get gaplessAdvances;
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
