import '../entities/playback_error.dart';

/// Why a 30-second preview plays instead of the whole song.
enum PreviewReason {
  /// No Spotify account connected: Deezer's preview is all there is.
  noSpotify,

  /// The connected account isn't Premium: Spotify only lets other apps
  /// play whole songs for Premium accounts.
  notPremium,

  /// The account isn't allowed in the app yet (Spotify's user list).
  notAllowed,

  /// No connection: the preview downloaded ahead of time plays.
  offline,

  /// Spotify has no reliable match for this song.
  trackUnavailable,

  /// No Spotify player could be woken on the phone.
  openApp,

  /// Spotify playback is switched off remotely for now.
  disabled,

  /// Spotify couldn't play it, for no reason it gave.
  other,
}

/// What the player is playing: the whole song (Spotify) or a preview, and
/// why. Pure: the player's state is handed in.
class PlaybackSource {
  /// Null when the whole song plays.
  final PreviewReason? previewReason;

  const PlaybackSource._(this.previewReason);

  static const fullSong = PlaybackSource._(null);

  bool get isFullSong => previewReason == null;

  /// [playsFullSong] is what really plays (not whether Spotify is on);
  /// [fallback] is the last reason Spotify gave for falling back, if any.
  factory PlaybackSource.of({
    required bool playsFullSong,
    required bool spotifyConnected,
    required bool premium,
    required bool notAllowed,
    required bool online,
    SpotifyFallbackReason? fallback,
  }) {
    if (playsFullSong) return fullSong;
    final PreviewReason reason;
    if (!spotifyConnected) {
      reason = PreviewReason.noSpotify;
    } else if (notAllowed) {
      reason = PreviewReason.notAllowed;
    } else if (!premium) {
      reason = PreviewReason.notPremium;
    } else if (!online) {
      reason = PreviewReason.offline;
    } else {
      reason = switch (fallback) {
        SpotifyFallbackReason.trackUnavailable => PreviewReason.trackUnavailable,
        SpotifyFallbackReason.openApp => PreviewReason.openApp,
        SpotifyFallbackReason.disabled => PreviewReason.disabled,
        null => PreviewReason.other,
      };
    }
    return PlaybackSource._(reason);
  }
}
