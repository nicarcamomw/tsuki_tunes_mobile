part of '../expanded_player_screen.dart';

/// Shuffle, previous, play/pause, next and repeat.
class _PlayerControls extends StatelessWidget {
  final AudioProvider audio;
  final LocaleProvider locale;
  final bool isPlaying;
  final bool isBuffering;
  final bool isShuffle;
  final PlaybackRepeatMode repeatMode;

  const _PlayerControls({
    required this.audio,
    required this.locale,
    required this.isPlaying,
    required this.isBuffering,
    required this.isShuffle,
    required this.repeatMode,
  });

  @override
  Widget build(BuildContext context) {
    final strings = locale.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          TapScale(
            semanticLabel: isShuffle ? strings.a11yShuffleOn : strings.a11yShuffleOff,
            onTap: audio.toggleShuffle,
            scaleDown: 0.8,
            child: _ModeIcon(icon: Icons.shuffle, on: isShuffle),
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
              icon: repeatMode == PlaybackRepeatMode.one
                  ? Icons.repeat_one
                  : Icons.repeat,
              on: repeatMode != PlaybackRepeatMode.off,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shuffle / repeat icon, lit with a dot under it while on.
class _ModeIcon extends StatelessWidget {
  final IconData icon;
  final bool on;

  const _ModeIcon({required this.icon, required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: on ? AppColors.accent : AppColors.textSecondary,
          ),
          if (on)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}
