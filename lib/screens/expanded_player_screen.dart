import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../core/constants/app_colors.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/rinnegan_visualizer.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/tap_scale.dart';
import 'main_navigation_screen.dart';

class ExpandedPlayerScreen extends StatefulWidget {
  const ExpandedPlayerScreen({super.key});

  @override
  State<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends State<ExpandedPlayerScreen>
    with SingleTickerProviderStateMixin {
  double _dragDy = 0;
  bool _showQueue = false;
  late final AnimationController _snapBack;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnimation = const AlwaysStoppedAnimation(0.0);
    _snapBack.addListener(() {
      setState(() => _dragDy = _snapAnimation.value);
    });
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragDy > 0) {
      setState(() => _dragDy = (_dragDy + details.delta.dy * 0.6).clamp(0, 400));
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDy > 80 || velocity > 400) {
      NavigationEvents.isPlayerExpanded.value = false;
      Navigator.of(context).pop();
    } else {
      final startValue = _dragDy;
      _snapAnimation = Tween<double>(begin: startValue, end: 0).animate(
        CurvedAnimation(parent: _snapBack, curve: Curves.easeOutCubic),
      );
      _snapBack.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final audio = context.read<AudioProvider>();
    final track = context.select<AudioProvider, Track?>((a) => a.currentTrack);
    final isPlaying = context.select<AudioProvider, bool>((a) => a.isPlaying);
    final isBuffering = context.select<AudioProvider, bool>((a) => a.isBuffering);
    final isShuffle = context.select<AudioProvider, bool>((a) => a.isShuffle);
    final isLoop = context.select<AudioProvider, bool>((a) => a.isLoop);
    final useSpotify = context.select<AudioProvider, bool>((a) => a.useSpotify);

    if (track == null) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          NavigationEvents.isPlayerExpanded.value = false;
        },
        child: Scaffold(
          backgroundColor: AppColors.bgDeep,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 28),
              onPressed: () {
                NavigationEvents.isPlayerExpanded.value = false;
                Navigator.of(context).pop();
              },
            ),
          ),
          body: Center(
            child: Text(
              strings.noTrackSelected,
              style: locale.getTextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final library = context.watch<LibraryProvider>();
    final isListened = library.isTrackListened(track.id);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        NavigationEvents.isPlayerExpanded.value = false;
      },
      child: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: Scaffold(
            backgroundColor: AppColors.bgDeep,
            body: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              size: 30, color: AppColors.textPrimary),
                          onPressed: () {
                            NavigationEvents.isPlayerExpanded.value = false;
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                strings.playingFrom,
                                style: locale.getTextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              Text(
                                track.albumTitle.isNotEmpty
                                    ? track.albumTitle
                                    : 'DEEZER PREVIEW',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.queue_music,
                              color: AppColors.textPrimary),
                          onPressed: () =>
                              setState(() => _showQueue = !_showQueue),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Art or Queue
                  if (_showQueue)
                    _buildQueueView(audio, locale)
                  else ...[
                  // Rinnegan Visualizer
                  Hero(
                    tag: 'player_art_${track.id}',
                    child: RinneganVisualizer(
                      isPlaying: isPlaying,
                      imageUrl: track.coverUrl,
                      size: MediaQuery.of(context).size.width * 0.72,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],

                const Spacer(),

                // Track info + listened + favorite
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textBright,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.fullArtistName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TapScale(
                        semanticLabel: isListened ? 'Unmark track' : 'Mark track as listened',
                        onTap: () {
                          if (isListened) {
                            library.unmarkTrack(track.id);
                          } else {
                            library.markTrack(track);
                          }
                        },
                        scaleDown: 0.8,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: OniMaskIcon(
                            isActive: isListened,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Consumer<AudioProvider>(
                    builder: (context, audioPos, _) => ProgressBar(
                      progress: audioPos.position,
                      total: audioPos.duration,
                      buffered: audioPos.bufferedPosition,
                      onSeek: audioPos.seek,
                      progressBarColor: AppColors.accent,
                      baseBarColor: AppColors.border,
                      bufferedBarColor: AppColors.borderGlow,
                      thumbColor: AppColors.accent,
                      thumbGlowColor: AppColors.accentGlow,
                      thumbRadius: 7.0,
                      timeLabelTextStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      TapScale(
                        semanticLabel: isShuffle ? 'Shuffle on' : 'Shuffle off',
                        onTap: audio.toggleShuffle,
                        scaleDown: 0.8,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shuffle,
                                size: 22,
                                color: isShuffle
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                              if (isShuffle)
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
                        ),
                      ),

                      // Previous
                      TapScale(
                        semanticLabel: 'Previous track',
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
                        semanticLabel: isPlaying ? 'Pause' : 'Play',
                        onTap: audio.togglePlay,
                        scaleDown: 0.88,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.accentGlow,
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: isBuffering
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              AppColors.textBright),
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 36,
                                    color: AppColors.textBright,
                                  ),
                          ),
                        ),
                      ),

                      // Next
                      TapScale(
                        semanticLabel: 'Next track',
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
                        semanticLabel: isLoop ? 'Repeat on' : 'Repeat off',
                        onTap: audio.toggleLoop,
                        scaleDown: 0.8,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 22,
                                color: isLoop
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                              if (isLoop)
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
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Device tag
                Text(
                  useSpotify ? 'SPOTIFY CONNECT' : 'DEEZER PREVIEW',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: AppColors.accent,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildQueueView(AudioProvider audio, LocaleProvider locale) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                locale.strings.queueTitle(audio.queue.length),
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: audio.queue.length,
                itemBuilder: (context, i) {
                  final t = audio.queue[i];
                  final isCur = audio.currentTrack?.id == t.id;
                  return ListTile(
                    dense: true,
                    leading: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: GoogleFonts.plusJakartaSans(
                        color: isCur
                            ? AppColors.accent
                            : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        color: isCur
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontWeight:
                            isCur ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      t.fullArtistName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                    ),
                    trailing: isCur
                        ? const Icon(Icons.equalizer,
                            color: AppColors.accent, size: 18)
                        : null,
                    onTap: () {
                      audio.playTrack(t);
                      setState(() => _showQueue = false);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
