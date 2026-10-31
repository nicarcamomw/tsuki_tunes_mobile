import '../../core/localization/app_strings.dart';

/// Why the current track could not play.
enum PlaybackError {
  /// Deezer has no 30 s preview for this track.
  noPreview,

  /// Network failure, or offline with the track not cached.
  network,

  /// The audio could not be decoded.
  formatUnsupported,

  /// Anything else.
  generic;

  String message(AppStrings strings, {bool isOnline = true}) => switch (this) {
        noPreview => strings.playbackNoPreview,
        network =>
          isOnline ? strings.playbackNetworkError : strings.offlineNoCache,
        formatUnsupported => strings.playbackFormatUnsupported,
        generic => strings.playbackError,
      };
}

/// Why playback fell back from Spotify to the Deezer preview.
enum SpotifyFallbackReason {
  /// No reliable Spotify match for the track.
  trackUnavailable,

  /// No Spotify device could be activated; the user should open the app.
  openApp;

  String message(AppStrings strings) => switch (this) {
        trackUnavailable => strings.spotifyTrackUnavailablePreview,
        openApp => strings.spotifyOpenAppPrompt,
      };
}
