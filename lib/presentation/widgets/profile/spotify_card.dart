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

  void _showSnack(String message, {SnackKind kind = SnackKind.info, Duration? duration}) {
    if (widget.hostContext.mounted) AppSnack.of(widget.hostContext).show(message, kind: kind, duration: duration);
  }

  Future<void> _disconnect() async {
    await _audio.spotify.disconnect();
    await _audio.updateSpotifyState();
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    final strings = widget.locale.strings;
    setState(() => _isConnecting = true);
    try {
      final success = await _audio.spotify.connect();
      _isConnecting = false;
      if (success) {
        ref.read(analyticsProvider).log('spotify_connected', {'premium': _audio.spotify.isPremium});
        await _audio.updateSpotifyState();
        if (mounted) setState(() {});
        _showSnack(strings.spotifySyncSuccess);
      } else if (_audio.spotify.isNotRegistered) {
        if (mounted) setState(() {});
        ref.read(analyticsProvider).log('spotify_connect_failed', {'reason': 'not_registered'});
        await _explainRestrictedAccess();
      } else {
        if (mounted) setState(() {});
        final msg = _audio.spotify.lastErrorKind == SpotifyConnectError.canceled
            ? strings.spotifyCanceledByUser
            : strings.spotifyConnectError;
        ref.read(analyticsProvider).log('spotify_connect_failed',
            {'canceled': msg == strings.spotifyCanceledByUser});
        _showSnack(msg, duration: const Duration(seconds: 3));
      }
    } catch (e) {
      _isConnecting = false;
      if (mounted) setState(() {});
      _showSnack(strings.spotifyConnectError, kind: SnackKind.error);
    }
  }

  /// The account isn't one of the few Spotify lets use the app (development
  /// mode): say so plainly, so it doesn't read as a broken app or account.
  Future<void> _explainRestrictedAccess() async {
    final host = widget.hostContext;
    if (!host.mounted) return;
    final locale = widget.locale;
    final strings = locale.strings;
    await showDialog<void>(
      context: host,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                strings.spotifyNotRegisteredTitle,
                style: locale.getTextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          strings.spotifyNotRegisteredMessage,
          style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              strings.spotifyNotRegisteredOk,
              style: locale.getTextStyle(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final strings = locale.strings;
    final spotify = _audio.spotify;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.circular(AppRadius.card),
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
                  borderRadius: BorderRadius.circular(AppRadius.card),
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
                        fontSize: AppFontSize.title,
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
                        fontSize: AppFontSize.micro,
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
                      icon: Icon(Icons.playlist_add_rounded, size: 18, color: AppColors.accent, semanticLabel: strings.importTitle),
                      tooltip: strings.importTitle,
                      onPressed: () async { Haptics.tap();
                        final host = widget.hostContext;
                        Navigator.pop(context);
                        await Future<void>.delayed(const Duration(milliseconds: 120));
                        if (host.mounted) unawaited(const SpotifyImportRoute().push<void>(host));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.launch_rounded, size: 16, color: AppColors.accent, semanticLabel: strings.a11yOpenExternal),
                      tooltip: strings.openSpotifyTooltip,
                      onPressed: () { Haptics.tap(); spotify.openSpotifyApp(); },
                    ),
                    TextButton(
                      onPressed: () { Haptics.remove(); _disconnect(); },
                      child: Text(
                        strings.spotifyDisconnect,
                        style: locale.getTextStyle(
                          fontSize: AppFontSize.micro,
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
                  onPressed: () { Haptics.confirm(); _connect(); },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                  ),
                  child: Text(
                    strings.spotifyConnect,
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.micro,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!spotify.isConnected && !_isConnecting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.spotifyLimitedNote,
                    style: locale.getTextStyle(fontSize: AppFontSize.micro, color: AppColors.textMuted),
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
                      fontSize: AppFontSize.micro,
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
