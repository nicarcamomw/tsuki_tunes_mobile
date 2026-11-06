import '../entities/artist.dart';
import '../entities/track.dart';

/// The player, as the rest of the app drives it: what plays, the queue and
/// the song radio. The engine behind it (previews or Spotify) is hidden.
abstract interface class PlaybackController {
  Track? get currentTrack;
  bool get isPlaying;

  /// Plays [track], replacing the queue with [newQueue] when given.
  Future<void> playTrack(Track track, {List<Track>? newQueue});
  Future<void> togglePlay();

  /// Puts [track] right after the current song.
  void playNext(Track track, {bool userQueued = true});
  void addToQueue(Track track);
  void addAllToQueue(List<Track> tracks);
  void removeFromQueue(int index);

  /// Starts an endless radio of songs like [seed]. False if it found none.
  Future<bool> startRadio(Track seed);

  /// Starts an endless radio of [artist]: their top songs and those of
  /// artists like them. False if it found none.
  Future<bool> startArtistRadio(Artist artist);
}
