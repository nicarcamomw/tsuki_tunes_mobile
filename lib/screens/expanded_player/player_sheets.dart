part of '../expanded_player_screen.dart';

/// Water drop opening the ambient mixer, with how many sounds are on.
class _AmbientButton extends ConsumerWidget {
  final LocaleProvider locale;

  const _AmbientButton({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(ambientProvider.select(
        (a) => a.isPlaying ? a.activeSounds.length : 0));
    final active = count > 0;
    return TapScale(
      semanticLabel: locale.strings.ambientTitle,
      onTap: () => AmbientMixerSheet.show(context),
      scaleDown: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.neonCyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 16,
              color: active ? AppColors.neonCyan : AppColors.textMuted,
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonCyan,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Moon button with the time left; opens the sleep timer choices.
class _SleepTimerButton extends ConsumerWidget {
  final AudioProvider audio;
  final LocaleProvider locale;

  const _SleepTimerButton({required this.audio, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = locale.strings;
    final isActive = ref.watch(audioProvider.select((a) => a.isSleepTimerActive));
    // Whole seconds: the label shows nothing finer, so no rebuild per tick.
    final remainingSeconds =
        ref.watch(audioProvider.select((a) => a.sleepTimerRemaining?.inSeconds));
    final remaining = remainingSeconds == null ? null : Duration(seconds: remainingSeconds);

    String label = '';
    if (remaining != null) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      label = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return TapScale(
      semanticLabel: strings.sleepTimer,
      onTap: () => _showSheet(context),
      scaleDown: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: AppColors.accent.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 16,
              color: isActive ? AppColors.accent : AppColors.textMuted,
              semanticLabel: strings.a11ySleepTimer,
            ),
            if (label.isNotEmpty || isActive) ...[
              const SizedBox(width: 4),
              Text(
                label.isNotEmpty ? label : strings.sleepTimerEndOfTrackShort,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final strings = locale.strings;
    // Label, whether it's the current choice, and the timer it sets
    // (null turns it off, zero stops at the end of the song).
    final options = <(String, bool, Duration?)>[
      (strings.sleepTimerOff, !audio.isSleepTimerActive, null),
      (
        strings.sleepTimerEndOfTrack,
        audio.isSleepTimerActive && audio.sleepTimerRemaining == null,
        Duration.zero,
      ),
      for (final minutes in const [15, 30, 45, 60])
        (
          strings.sleepTimerMinutes(minutes),
          audio.sleepTimerOriginalMinutes == minutes,
          Duration(minutes: minutes),
        ),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.bedtime_outlined, color: AppColors.accent, size: 18, semanticLabel: strings.a11ySleepTimer),
                    const SizedBox(width: 8),
                    Text(
                      strings.sleepTimer,
                      style: locale.getTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final (label, isSelected, duration) in options)
                  _buildOption(label, isSelected, () {
                    audio.setSleepTimer(duration);
                    SemanticsService.sendAnnouncement(View.of(context), label, TextDirection.ltr);
                    Navigator.pop(context);
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOption(String label, bool isSelected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 18, semanticLabel: locale.strings.a11ySelected),
          ],
        ),
      ),
    ),
    );
  }
}

/// The song's menu: BPM, queue, radio, lyrics, album and artist.
void _showSongOptionsSheet(
  BuildContext context,
  Track track,
  LocaleProvider locale, {
  required bool radioActive,
  required VoidCallback onShowQueue,
  required VoidCallback onOpenLyrics,
  required VoidCallback onOpenAlbum,
}) {
  final strings = locale.strings;
  final bpm = BpmService.shared.cached(track.id);

  Widget optionTile({
    required IconData icon,
    required String label,
    String? trailing,
    bool accentIcon = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: accentIcon ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  trailing,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgMid,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Track header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: track.coverUrl,
                              memCacheWidth: imageCacheSize(context, 44),
                              fit: BoxFit.cover,
                            )
                          : Container(color: AppColors.bgHover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textBright,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.fullArtistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: locale.getTextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              // BPM info
              if (bpm != null)
                optionTile(
                  icon: Icons.speed,
                  label: 'BPM',
                  trailing: '${bpm.round()}',
                ),
              // Save the song to a playlist
              optionTile(
                icon: Icons.playlist_add,
                label: strings.addToPlaylist,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                  showPlaylistSelector(context, track);
                },
              ),
              // Queue
              optionTile(
                icon: Icons.queue_music,
                label: strings.a11yQueue,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                  onShowQueue();
                },
              ),
              // Radio
              optionTile(
                icon: Icons.sensors,
                label: radioActive ? strings.radioTune : strings.radioStart,
                accentIcon: radioActive,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                  if (radioActive) {
                    showRadioControlSheet(context);
                  } else {
                    startRadioWithFeedback(context, track,
                        bottomMargin:
                            MediaQuery.paddingOf(context).bottom + 12);
                  }
                },
              ),
              // Lyrics full view
              optionTile(
                icon: Icons.lyrics_outlined,
                label: strings.a11yLyrics,
                onTap: () {
                  Navigator.pop(context);
                  onOpenLyrics();
                },
              ),
              // Go to album
              if (track.albumId.isNotEmpty)
                optionTile(
                  icon: Icons.album,
                  label: track.albumTitle.isNotEmpty
                      ? track.albumTitle
                      : strings.unknownAlbum,
                  onTap: () {
                    Navigator.pop(context);
                    onOpenAlbum();
                  },
                ),
              // Go to artist
              if (track.artistId.isNotEmpty)
                optionTile(
                  icon: Icons.person,
                  label: track.artistName,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pop();
                    _openArtistOf(track);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Opens the artist page of [track] on the app navigator.
void _openArtistOf(Track track) {
  appNavigatorKey.currentState?.push(
    CyberPageRoute(
      builder: (_) => ArtistDetailScreen(
        artist: Artist(
          id: track.artistId,
          name: track.artistName,
          pictureUrl: track.coverUrl,
        ),
      ),
    ),
  );
}
