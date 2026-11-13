import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/domain/entities/playback_error.dart';
import 'package:tsuki_tunes_mobile/domain/logic/playback_source.dart';

// U2: the badge says what really plays, and why a preview does.
void main() {
  PlaybackSource of({
    bool full = false,
    bool connected = true,
    bool premium = true,
    bool notAllowed = false,
    bool online = true,
    SpotifyFallbackReason? fallback,
  }) =>
      PlaybackSource.of(
        playsFullSong: full,
        spotifyConnected: connected,
        premium: premium,
        notAllowed: notAllowed,
        online: online,
        fallback: fallback,
      );

  test('the whole song, when it really plays from Spotify', () {
    expect(of(full: true).isFullSong, isTrue);
    expect(of(full: true).previewReason, isNull);
  });

  test('a preview with Spotify connected says so, with Spotify\'s reason', () {
    expect(of(fallback: SpotifyFallbackReason.trackUnavailable).previewReason, PreviewReason.trackUnavailable);
    expect(of(fallback: SpotifyFallbackReason.openApp).previewReason, PreviewReason.openApp);
    expect(of(fallback: SpotifyFallbackReason.disabled).previewReason, PreviewReason.disabled);
    expect(of().previewReason, PreviewReason.other);
  });

  test('the account comes first: none, not allowed, not Premium', () {
    expect(of(connected: false, fallback: SpotifyFallbackReason.trackUnavailable).previewReason,
        PreviewReason.noSpotify);
    expect(of(notAllowed: true, premium: false).previewReason, PreviewReason.notAllowed);
    expect(of(premium: false, fallback: SpotifyFallbackReason.openApp).previewReason, PreviewReason.notPremium);
  });

  test('offline, a Premium account plays the downloaded preview', () {
    expect(of(online: false, fallback: SpotifyFallbackReason.trackUnavailable).previewReason, PreviewReason.offline);
  });
}
