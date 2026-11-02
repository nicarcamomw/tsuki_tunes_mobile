part of '../profile_bottom_sheet.dart';

/// Spotify account card: connect, disconnect and open the app, with the
/// playback mode the connection gives underneath.
class _SpotifyCard extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final LocaleProvider locale;

  const _SpotifyCard({required this.hostContext, required this.locale});

  @override
  ConsumerState<_SpotifyCard> createState() => _SpotifyCardState();
}

class _SpotifyCardState extends ConsumerState<_SpotifyCard> {
  bool _isConnecting = false;

  AudioProvider get _audio => ref.read(audioProvider);
  SpotifyService get _spotify => _audio.spotify;

  void _showSnack(SnackBar snackBar) {
    if (widget.hostContext.mounted) {
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(snackBar);
    }
  }

  SnackBar _plainSnack(String message, Duration duration) {
    return SnackBar(
      content: Text(
        message,
        style: widget.locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
      ),
      backgroundColor: AppColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      duration: duration,
    );
  }

  Future<void> _disconnect() async {
    await _spotify.disconnect();
    await _audio.updateSpotifyState();
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    final strings = widget.locale.strings;
    setState(() => _isConnecting = true);
    try {
      final success = await _spotify.connect();
      _isConnecting = false;
      if (success) {
        ProductAnalytics.instance.log('spotify_connected', {'premium': _spotify.isPremium});
        await _audio.updateSpotifyState();
        if (mounted) setState(() {});
        _showSnack(_plainSnack(strings.spotifySyncSuccess, const Duration(seconds: 2)));
      } else {
        if (mounted) setState(() {});
        final rawError = _spotify.lastError;
        String msg = strings.spotifyConnectError;
        if (rawError != null) {
          final lower = rawError.toLowerCase();
          if (lower.contains('cancel') || lower.contains('cancelada') || lower.contains('canceled_by_user')) {
            msg = strings.spotifyCanceledByUser;
          }
        }
        ProductAnalytics.instance.log('spotify_connect_failed',
            {'canceled': msg == strings.spotifyCanceledByUser});
        _showSnack(_plainSnack(msg, const Duration(seconds: 3)));
      }
    } catch (e) {
      _isConnecting = false;
      if (mounted) setState(() {});
      _showSnack(SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 18, semanticLabel: strings.a11yPlaybackError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.spotifyConnectError,
                style: widget.locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.error, width: 1.2),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final spotify = _spotify;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: spotify.isConnected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.music_note,
                    color: Colors.white, size: 20, semanticLabel: strings.a11yMusicNote),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spotify',
                      style: locale.getTextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                    ),
                    Text(
                      _isConnecting
                          ? strings.spotifyConnecting
                          : spotify.isConnected
                              ? (spotify.isPremium
                                  ? 'Premium · ${spotify.displayName ?? strings.spotifyDefaultUser}'
                                  : '${strings.spotifyConnected} · ${spotify.displayName ?? strings.spotifyDefaultUser}')
                              : strings.spotifyNotConnected,
                      style: locale.getTextStyle(
                        fontSize: 10,
                        color: _isConnecting
                            ? AppColors.accent
                            : spotify.isConnected
                                ? AppColors.accent
                                : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (spotify.isConnected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.launch_rounded, size: 16, color: AppColors.accent, semanticLabel: strings.a11yOpenExternal),
                      tooltip: strings.openSpotifyTooltip,
                      onPressed: () => spotify.openSpotifyApp(),
                    ),
                    TextButton(
                      onPressed: _disconnect,
                      child: Text(
                        strings.spotifyDisconnect,
                        style: locale.getTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              else if (_isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                OutlinedButton(
                  onPressed: _connect,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                  ),
                  child: Text(
                    strings.spotifyConnect,
                    style: locale.getTextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (spotify.isConnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  spotify.isPremium ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    spotify.isPremium
                        ? (spotify.activeDeviceName != null
                            ? strings.spotifyActiveDevice(spotify.activeDeviceName!)
                            : strings.spotifyPremiumActive)
                        : strings.spotifyStandardPreview,
                    style: locale.getTextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
