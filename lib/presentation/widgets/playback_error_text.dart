import '../../core/localization/app_strings.dart';
import '../../domain/entities/playback_error.dart';

/// What the player shows for each [PlaybackError], in the app's language.
extension PlaybackErrorText on PlaybackError {
  String message(AppStrings strings, {bool isOnline = true}) => switch (this) {
        PlaybackError.noPreview => strings.playbackNoPreview,
        PlaybackError.network =>
          isOnline ? strings.playbackNetworkError : strings.offlineNoCache,
        PlaybackError.formatUnsupported => strings.playbackFormatUnsupported,
        PlaybackError.generic => strings.playbackError,
      };
}

/// What the player says when Spotify falls back to the preview.
extension SpotifyFallbackReasonText on SpotifyFallbackReason {
  String message(AppStrings strings) => switch (this) {
        SpotifyFallbackReason.trackUnavailable => strings.spotifyTrackUnavailablePreview,
        SpotifyFallbackReason.openApp => strings.spotifyOpenAppPrompt,
        SpotifyFallbackReason.disabled => strings.spotifyDisabledPreview,
      };
}
