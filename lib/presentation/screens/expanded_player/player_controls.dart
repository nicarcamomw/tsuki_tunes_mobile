part of '../expanded_player_screen.dart';

/// Shuffle, previous, play/pause, next and repeat.
class _PlayerControls extends StatelessWidget {
  final AudioProvider audio;
  final LocaleProvider locale;
  final bool isPlaying;
  final bool isBuffering;
  final ShuffleMode shuffleMode;
  final PlaybackRepeatMode repeatMode;

  const _PlayerControls({
    required this.audio,
    required this.locale,
    required this.isPlaying,
    required this.isBuffering,
    required this.shuffleMode,
    required this.repeatMode,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    final isShuffle = shuffleMode != ShuffleMode.off;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          TapScale(
            semanticLabel: switch (shuffleMode) {
              ShuffleMode.off => strings.a11yShuffleOff,
              ShuffleMode.on => strings.a11yShuffleOn,
              ShuffleMode.smart => strings.a11yShuffleSmart,
            },
            // Off → shuffle → shuffle with recommendations.
            onTap: () {
              HapticFeedback.selectionClick();
              final mode = audio.cycleShuffle();
              showTrackSnack(
                context,
                switch (mode) {
                  ShuffleMode.off => strings.shuffleOffToast,
                  ShuffleMode.on => strings.shuffleOnToast,
                  ShuffleMode.smart => strings.shuffleSmartToast,
                },
                bottom: MediaQuery.paddingOf(context).bottom + 12,
              );
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              showSmartShuffleSheet(context);
            },
            scaleDown: 0.8,
            child: _ModeIcon(
              icon: ShuffleModeIcon(
                mode: shuffleMode,
                size: 22,
                color: isShuffle ? PlayerTint.of(context) : AppColors.textSecondary,
              ),
              on: isShuffle,
            ),
          ),

          // Previous
          TapScale(
            semanticLabel: strings.a11yPrevious,
            onTap: audio.previous,
            scaleDown: 0.85,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.skip_previous,
                  size: 34, color: AppColors.textPrimary),
            ),
          ),

          // Play/Pause
          TapScale(
            semanticLabel: isPlaying ? strings.a11yPause : strings.a11yPlay,
            onTap: isBuffering ? null : audio.togglePlay,
            scaleDown: 0.88,
            child: _PulsingGlowPlay(
              isPlaying: isPlaying,
              isBuffering: isBuffering,
            ),
          ),

          // Next
          TapScale(
            semanticLabel: strings.a11yNext,
            onTap: audio.next,
            scaleDown: 0.85,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.skip_next,
                  size: 34, color: AppColors.textPrimary),
            ),
          ),

          // Repeat
          TapScale(
            semanticLabel: switch (repeatMode) {
              PlaybackRepeatMode.off => strings.repeatOff,
              PlaybackRepeatMode.all => strings.repeatAll,
              PlaybackRepeatMode.one => strings.repeatOne,
            },
            onTap: audio.toggleRepeat,
            scaleDown: 0.8,
            child: _ModeIcon(
              icon: Icon(
                repeatMode == PlaybackRepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                size: 22,
                color: repeatMode != PlaybackRepeatMode.off
                    ? PlayerTint.of(context)
                    : AppColors.textSecondary,
              ),
              on: repeatMode != PlaybackRepeatMode.off,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shuffle / repeat icon, with a dot under it while on.
class _ModeIcon extends StatelessWidget {
  final Widget icon;
  final bool on;

  const _ModeIcon({required this.icon, required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (on)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PlayerTint.of(context),
              ),
            ),
        ],
      ),
    );
  }
}
