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

/// Why connecting a Spotify account failed (SpotifyService.connect). The
/// text Spotify or the system gave stays in `lastError`, for the logs.
enum SpotifyConnectError {
  /// The person closed or cancelled the Spotify sign-in.
  canceled,

  /// The account isn't on the app's allow list (development mode).
  notRegistered,

  /// The sign-in answer didn't match what was asked (CSRF check).
  stateMismatch,

  /// Spotify answered without the code to sign in with.
  noAuthCode,

  /// Spotify refused the sign-in or answered with an error.
  server,

  /// No connection, or the request failed on the way.
  network,

  /// Anything else.
  other,
}
