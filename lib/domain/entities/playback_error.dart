/// Why the current track could not play.
enum PlaybackError {
  /// Deezer has no 30 s preview for this track.
  noPreview,

  /// Network failure, or offline with the track not cached.
  network,

  /// The audio could not be decoded.
  formatUnsupported,

  /// Anything else.
  generic,
}

/// Why playback fell back from Spotify to the Deezer preview.
enum SpotifyFallbackReason {
  /// No reliable Spotify match for the track.
  trackUnavailable,

  /// No Spotify device could be activated; the user should open the app.
  openApp,

  /// Spotify playback is switched off remotely for now (kill switch).
  disabled,
}
