import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/radio_control_sheet.dart';
import '../widgets/rinnegan_visualizer.dart';
import '../widgets/tap_scale.dart';
import '../widgets/title_marquee.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'expanded_player/lyrics_view.dart';
import 'expanded_player/queue_panel.dart';
import 'expanded_player/sleep_timer_button.dart';
import 'main_navigation_screen.dart';

enum _CenterViewMode { artwork, lyrics, queue }

class ExpandedPlayerScreen extends StatefulWidget {
  const ExpandedPlayerScreen({super.key});

  @override
  State<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends State<ExpandedPlayerScreen>
    with SingleTickerProviderStateMixin {
  double _dragDy = 0;
  bool _reduceMotion = false;
  _CenterViewMode _viewMode = _CenterViewMode.artwork;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
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
      if (_reduceMotion) {
        setState(() => _dragDy = 0);
      } else {
        final startValue = _dragDy;
        _snapAnimation = Tween<double>(begin: startValue, end: 0).animate(
          CurvedAnimation(parent: _snapBack, curve: Curves.easeOutCubic),
        );
        _snapBack.forward(from: 0);
      }
    }
  }

  void _navigateToSource(BuildContext context, Track track) {
    if (track.albumId.isNotEmpty) {
      Navigator.of(context).pop();
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlbumDetailScreen(
            album: Album(
              id: track.albumId,
              title: track.albumTitle.isNotEmpty ? track.albumTitle : context.read<LocaleProvider>().strings.unknownAlbum,
              coverUrl: track.coverUrl,
              artistId: track.artistId,
              artistName: track.artistName,
            ),
          ),
        ),
      );
    } else if (track.artistId.isNotEmpty) {
      Navigator.of(context).pop();
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
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
    final repeatMode = context.select<AudioProvider, PlaybackRepeatMode>((a) => a.repeatMode);
    final useSpotify = context.select<AudioProvider, bool>((a) => a.useSpotify);
    final radioActive = context.select<AudioProvider, bool>((a) => a.isRadioActive);
    final playbackError =
        context.select<AudioProvider, PlaybackError?>((a) => a.lastPlaybackError);

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
              tooltip: strings.a11yCollapsePlayer,
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
                  _buildTopBar(locale, strings, track, radioActive),

                  // Art, Lyrics or Queue
                  if (_viewMode == _CenterViewMode.queue)
                    PlayerQueuePanel(
                      onSwitchToArtwork: () => setState(() => _viewMode = _CenterViewMode.artwork),
                    )
                  else if (_viewMode == _CenterViewMode.lyrics)
                    PlayerLyricsView(track: track)
                  else ...[
                    const Spacer(),
                    ExcludeSemantics(
                    child: Hero(
                      tag: 'player_art_${track.id}',
                      child: RinneganVisualizer(
                        isPlaying: isPlaying,
                        imageUrl: track.coverUrl,
                        size: MediaQuery.of(context).size.width * 0.72,
                      ),
                    ),
                    ),
                    const SizedBox(height: 24),
                    const Spacer(),
                  ],

                  _buildTrackInfo(locale, strings, track, isListened, library),
                  const SizedBox(height: 16),
                  _buildProgressBar(locale),

                  if (playbackError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 14, semanticLabel: strings.a11yPlaybackError),
                          const SizedBox(width: 6),
                          Text(
                            playbackError.message(strings),
                            style: locale.getTextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  _buildControls(locale, strings, audio, isPlaying, isBuffering, isShuffle, repeatMode),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text(
                          useSpotify ? 'SPOTIFY CONNECT' : 'DEEZER PREVIEW',
                          style: locale.getTextStyle(
                            fontSize: 9,
                            color: AppColors.accent,
                            letterSpacing: 2,
                          ),
                        ),
                        const PlayerSleepTimerButton(),
                      ],
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

  Widget _buildTopBar(LocaleProvider locale, dynamic strings, Track track, bool radioActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: strings.a11yCollapsePlayer,
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 30, color: AppColors.textPrimary),
            onPressed: () {
              NavigationEvents.isPlayerExpanded.value = false;
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () => _navigateToSource(context, track),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        const SizedBox(width: 4),
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.albumTitle.isNotEmpty
                          ? track.albumTitle
                          : (track.artistName.isNotEmpty
                              ? track.artistName
                              : 'DEEZER PREVIEW'),
                      style: locale.getTextStyle(
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
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: radioActive
                    ? '${strings.a11yRadio}: ${strings.radioTune}'
                    : strings.radioStart,
                icon: Icon(
                  Icons.sensors,
                  color: radioActive
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (radioActive) {
                    showRadioControlSheet(context);
                  } else {
                    startRadioWithFeedback(context, track,
                        bottomMargin:
                            MediaQuery.paddingOf(context).bottom +
                                12);
                  }
                },
              ),
              IconButton(
                tooltip: strings.a11yLyrics,
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: _viewMode == _CenterViewMode.lyrics
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_viewMode == _CenterViewMode.lyrics) {
                      _viewMode = _CenterViewMode.artwork;
                    } else {
                      _viewMode = _CenterViewMode.lyrics;
                    }
                  });
                },
              ),
              IconButton(
                tooltip: strings.a11yQueue,
                icon: Icon(
                  Icons.queue_music,
                  color: _viewMode == _CenterViewMode.queue
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _viewMode =
                        _viewMode == _CenterViewMode.queue
                            ? _CenterViewMode.artwork
                            : _CenterViewMode.queue;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackInfo(LocaleProvider locale, dynamic strings, Track track, bool isListened, LibraryProvider library) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: TitleMarquee(
                    text: track.title,
                    style: locale.getTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (track.artistId.isNotEmpty) {
                      Navigator.of(context).pop();
                      appNavigatorKey.currentState?.push(
                        MaterialPageRoute(
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
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      track.fullArtistName,
                      style: locale.getTextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TapScale(
            semanticLabel: isListened ? strings.a11yUnmarkListened : strings.a11yMarkListened,
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
    );
  }

  Widget _buildProgressBar(LocaleProvider locale) {
    return Padding(
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
          timeLabelTextStyle: locale.getTextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(LocaleProvider locale, dynamic strings, AudioProvider audio, bool isPlaying, bool isBuffering, bool isShuffle, PlaybackRepeatMode repeatMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TapScale(
            semanticLabel: isShuffle ? strings.a11yShuffleOn : strings.a11yShuffleOff,
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

          TapScale(
            semanticLabel: isPlaying ? strings.a11yPause : strings.a11yPlay,
            onTap: isBuffering ? null : audio.togglePlay,
            scaleDown: 0.88,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                boxShadow: [
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

          TapScale(
            semanticLabel: switch (repeatMode) {
              PlaybackRepeatMode.off => strings.repeatOff,
              PlaybackRepeatMode.all => strings.repeatAll,
              PlaybackRepeatMode.one => strings.repeatOne,
            },
            onTap: audio.toggleRepeat,
            scaleDown: 0.8,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    repeatMode == PlaybackRepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    size: 22,
                    color: repeatMode != PlaybackRepeatMode.off
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  if (repeatMode != PlaybackRepeatMode.off)
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
    );
  }
}
