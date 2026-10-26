import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/synced_lyrics.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/lyrics_service.dart';
import '../services/translation_service.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/radio_control_sheet.dart';
import '../widgets/rinnegan_visualizer.dart';
import '../widgets/tap_scale.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
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
  SyncedLyrics? _lyrics;
  bool _isLoadingLyrics = false;
  String? _lastLoadedTrackId;
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastActiveLyricIndex = -1;
  bool _userInteracting = false;
  Timer? _resumeAutoScrollTimer;
  final Map<int, GlobalKey> _lineKeys = {};
  late final AnimationController _snapBack;
  late Animation<double> _snapAnimation;

  bool _showTranslation = false;
  bool _isTranslating = false;
  bool _isDownloadingModel = false;
  List<String>? _translatedLines;
  String? _lastTranslatedTrackId;

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
    _lyricsScrollController.dispose();
    _resumeAutoScrollTimer?.cancel();
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
                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    _lastActiveLyricIndex = -1;
                                    _lineKeys.clear();
                                    _userInteracting = false;
                                    _resumeAutoScrollTimer?.cancel();
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
                  ),

                  // Art, Lyrics or Queue
                  if (_viewMode == _CenterViewMode.queue)
                    _buildQueueView(audio, locale)
                  else if (_viewMode == _CenterViewMode.lyrics)
                    _buildLyricsView(audio, locale, track)
                  else ...[
                    const Spacer(),
                    // Rinnegan Visualizer
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

                // Track info + listened + favorite
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: _TitleMarquee(
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
                      timeLabelTextStyle: locale.getTextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

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

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
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
                ),

                const SizedBox(height: 12),

                // Device tag + Sleep Timer
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
                      _buildSleepTimerButton(context, audio, locale),
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

  Widget _buildSleepTimerButton(BuildContext context, AudioProvider audio, LocaleProvider locale) {
    final strings = locale.strings;
    final isActive = context.select<AudioProvider, bool>((a) => a.isSleepTimerActive);
    final remaining = context.select<AudioProvider, Duration?>((a) => a.sleepTimerRemaining);

    String label = '';
    if (remaining != null) {
      final m = remaining.inMinutes;
      final s = remaining.inSeconds % 60;
      label = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return TapScale(
      semanticLabel: strings.sleepTimer,
      onTap: () => _showSleepTimerSheet(context, audio, locale),
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
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: locale.getTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ] else if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                strings.sleepTimerEndOfTrackShort,
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

  void _showSleepTimerSheet(BuildContext context, AudioProvider audio, LocaleProvider locale) {
    final strings = locale.strings;
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
                _sleepTimerOption(
                  strings.sleepTimerOff,
                  !audio.isSleepTimerActive,
                  locale,
                  () { audio.setSleepTimer(null); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerOff, TextDirection.ltr); Navigator.pop(context); },
                ),
                _sleepTimerOption(
                  strings.sleepTimerEndOfTrack,
                  audio.isSleepTimerActive && audio.sleepTimerRemaining == null,
                  locale,
                  () { audio.setSleepTimer(Duration.zero); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerEndOfTrack, TextDirection.ltr); Navigator.pop(context); },
                ),
                _sleepTimerOption(
                  strings.sleepTimerMinutes(15),
                  audio.sleepTimerOriginalMinutes == 15,
                  locale,
                  () { audio.setSleepTimer(const Duration(minutes: 15)); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerMinutes(15), TextDirection.ltr); Navigator.pop(context); },
                ),
                _sleepTimerOption(
                  strings.sleepTimerMinutes(30),
                  audio.sleepTimerOriginalMinutes == 30,
                  locale,
                  () { audio.setSleepTimer(const Duration(minutes: 30)); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerMinutes(30), TextDirection.ltr); Navigator.pop(context); },
                ),
                _sleepTimerOption(
                  strings.sleepTimerMinutes(45),
                  audio.sleepTimerOriginalMinutes == 45,
                  locale,
                  () { audio.setSleepTimer(const Duration(minutes: 45)); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerMinutes(45), TextDirection.ltr); Navigator.pop(context); },
                ),
                _sleepTimerOption(
                  strings.sleepTimerMinutes(60),
                  audio.sleepTimerOriginalMinutes == 60,
                  locale,
                  () { audio.setSleepTimer(const Duration(minutes: 60)); SemanticsService.sendAnnouncement(View.of(context),strings.sleepTimerMinutes(60), TextDirection.ltr); Navigator.pop(context); },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sleepTimerOption(String label, bool isSelected, LocaleProvider locale, VoidCallback onTap) {
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

  Widget _buildQueueView(AudioProvider audio, LocaleProvider locale) {
    // The queue list is mutated in place (radio refills, reorders), so
    // rebuild on a fingerprint of it rather than on identity.
    return Expanded(
      child: Selector<AudioProvider, (int, int, bool, RadioStatus, RadioMode)>(
        selector: (_, a) => (
          Object.hashAll(a.queue.map((t) => t.id)),
          a.currentIndex,
          a.isRadioActive,
          a.radioStatus,
          a.radioMode,
        ),
        builder: (context, _, __) => _buildQueuePanel(audio, locale),
      ),
    );
  }

  Widget _buildRadioBanner(AudioProvider audio, LocaleProvider locale) {
    final strings = locale.strings;
    final seed = audio.radioSeed;
    if (seed == null) return const SizedBox.shrink();
    final modeLabel = switch (audio.radioMode) {
      RadioMode.familiar => strings.radioModeFamiliar,
      RadioMode.balanced => strings.radioModeBalanced,
      RadioMode.adventurous => strings.radioModeAdventurous,
    };
    return Semantics(
      button: true,
      label: '${strings.a11yRadio}. ${strings.radioBasedOn(seed.title)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showRadioControlSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accent.withValues(alpha: 0.14),
              AppColors.neonPurple.withValues(alpha: 0.06),
            ]),
          ),
          child: Row(
            children: [
              const Icon(Icons.all_inclusive, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.radioLabel} · ${modeLabel.toUpperCase()}',
                      style: locale.getTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      strings.radioBasedOn(seed.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  strings.radioTune,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioFooter(AudioProvider audio, LocaleProvider locale) {
    final status = audio.radioStatus;
    final warn =
        status == RadioStatus.offline || status == RadioStatus.exhausted;
    final color = warn ? AppColors.warning : AppColors.textMuted;
    return Padding(
      key: const ValueKey('radio_footer'),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == RadioStatus.loading)
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.accent),
              )
            else
              Icon(warn ? Icons.info_outline : Icons.all_inclusive,
                  size: 14, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                radioStatusLabel(locale.strings, status),
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuePanel(AudioProvider audio, LocaleProvider locale) {
    final queue = audio.queue;
    final strings = locale.strings;
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgMid.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderGlow.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music,
                            color: AppColors.accent, size: 16, semanticLabel: strings.a11yQueue),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            strings.queueUpNext,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${queue.length}',
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
                  const SizedBox(width: 8),
                  if (queue.length > 1)
                    Semantics(
                      button: true,
                      label: strings.queueClearLabel,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          final savedQueue = List<Track>.from(queue);
                          audio.clearQueue();
                          SemanticsService.sendAnnouncement(View.of(context),strings.queueClearLabel, TextDirection.ltr);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          final navBarPadding = MediaQuery.of(context).padding.bottom;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.queueClearLabel,
                                style: locale.getTextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textBright,
                                ),
                              ),
                              backgroundColor: AppColors.bgCard,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              margin: EdgeInsets.only(bottom: navBarPadding + 12, left: 16, right: 16),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: strings.undo,
                                textColor: AppColors.accent,
                                onPressed: () {
                                  for (final t in savedQueue) {
                                    audio.addToQueue(t);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgHover,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_sweep_outlined,
                                  size: 13, color: AppColors.textMuted, semanticLabel: strings.a11yClearQueue),
                              const SizedBox(width: 4),
                              Text(
                                strings.queueClear,
                                style: locale.getTextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            if (audio.isRadioActive) _buildRadioBanner(audio, locale),
            if (queue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  strings.swipeToRemoveHint,
                  style: locale.getTextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              size: 44,
                              color: AppColors.textMuted.withValues(alpha: 0.4),
                              semanticLabel: strings.a11yEmptyQueue),
                          const SizedBox(height: 10),
                          Text(
                            strings.queueEmpty,
                            style: locale.getTextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.queueEmptySubtitle,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      footer: audio.isRadioActive
                          ? _buildRadioFooter(audio, locale)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      itemCount: queue.length,
                      onReorderItem: (oldIndex, newIndex) {
                        audio.reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, i) {
                        final t = queue[i];
                        final isCur = audio.currentTrack?.id == t.id;
                        return Dismissible(
                          key: ValueKey('queue_${t.id}_$i'),
                          direction: isCur ? DismissDirection.none : DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.delete_outline, color: AppColors.accent, size: 20, semanticLabel: strings.a11yRemoveFromQueue),
                          ),
                          onDismissed: (_) {
                            audio.removeFromQueue(i);
                            HapticFeedback.lightImpact();
                            SemanticsService.sendAnnouncement(View.of(context),strings.removedFromQueue, TextDirection.ltr);
                            final navPad = MediaQuery.of(context).padding.bottom;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.removedFromQueue,
                                  style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                                ),
                                backgroundColor: AppColors.bgCard,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                margin: EdgeInsets.only(bottom: navPad + 12, left: 16, right: 16),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: isCur
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : AppColors.bgMid.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCur
                                  ? AppColors.accent.withValues(alpha: 0.5)
                                  : AppColors.border.withValues(alpha: 0.4),
                              width: isCur ? 1.2 : 0.8,
                            ),
                          ),
                          child: Semantics(
                            label: '${t.title}, ${t.fullArtistName}',
                            child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              audio.playTrack(t);
                              setState(
                                  () => _viewMode = _CenterViewMode.artwork);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: isCur
                                        ? Icon(Icons.equalizer,
                                            color: AppColors.accent, size: 16, semanticLabel: strings.a11yNowPlaying)
                                        : Text(
                                            (i + 1).toString().padLeft(2, '0'),
                                            style: locale.getTextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  ExcludeSemantics(child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: t.coverUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: t.coverUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: AppColors.bgHover,
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: AppColors.bgHover,
                                              ),
                                            )
                                          : Container(
                                              color: AppColors.bgHover,
                                            ),
                                    ),
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          t.title,
                                          style: locale.getTextStyle(
                                            color: isCur
                                                ? AppColors.accent
                                                : AppColors.textBright,
                                            fontWeight: isCur
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t.fullArtistName,
                                          style: locale.getTextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (radioReasonLabel(strings,
                                                audio.radioReasonFor(t.id))
                                            case final why?)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              why,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: locale.getTextStyle(
                                                color: AppColors.neonCyan
                                                    .withValues(alpha: 0.75),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: strings.queueRemoveLabel,
                                    child: GestureDetector(
                                      onTap: () {
                                        audio.removeFromQueue(i);
                                        HapticFeedback.lightImpact();
                                        SemanticsService.sendAnnouncement(View.of(context),strings.removedFromQueue, TextDirection.ltr);
                                        final navPad = MediaQuery.of(context).padding.bottom;
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              strings.removedFromQueue,
                                              style: locale.getTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBright),
                                            ),
                                            backgroundColor: AppColors.bgCard,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            margin: EdgeInsets.only(bottom: navPad + 12, left: 16, right: 16),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Center(
                                          child: Icon(
                                            Icons.close,
                                            color: AppColors.textMuted,
                                            size: 16,
                                            semanticLabel: strings.a11yRemoveFromQueue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 6),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: AppColors.textMuted,
                                        size: 20,
                                        semanticLabel: strings.a11yReorder,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
  }

  Future<void> _loadLyricsForTrack(Track track) async {
    if (_lastLoadedTrackId == track.id && _lyrics != null) return;
    _lastLoadedTrackId = track.id;
    _lineKeys.clear();
    _lastActiveLyricIndex = -1;
    _userInteracting = false;
    _resumeAutoScrollTimer?.cancel();

    setState(() {
      _isLoadingLyrics = true;
      _lyrics = null;
      _showTranslation = false;
      _translatedLines = null;
      _isTranslating = false;
      _isDownloadingModel = false;
    });

    try {
      final lyrics =
          await LyricsService().getLyrics(track.title, track.artistName);
      if (!mounted || _lastLoadedTrackId != track.id) return;
      setState(() {
        _lyrics = lyrics;
        _isLoadingLyrics = false;
        _lastActiveLyricIndex = -1;
        _lineKeys.clear();
      });
    } catch (e) {
      if (mounted && _lastLoadedTrackId == track.id) {
        setState(() {
          _lyrics = null;
          _isLoadingLyrics = false;
        });
      }
    }
  }

  Widget _buildLyricsView(
      AudioProvider audio, LocaleProvider locale, Track track) {
    if (_lastLoadedTrackId != track.id && !_isLoadingLyrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLyricsForTrack(track);
      });
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgMid.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderGlow.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lyrics,
                            color: AppColors.accent, size: 16, semanticLabel: locale.strings.a11yLyrics),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            locale.strings.lyrics,
                            style: locale.getTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_lyrics?.isSynced == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            locale.strings.syncedTapToSeek,
                            style: locale.getTextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      if (_lyrics != null && !_lyrics!.isInstrumental && _lyrics!.plainLyrics.isNotEmpty)
                        _buildTranslateButton(locale, track),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            if (_showTranslation && _translatedLines != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                color: AppColors.accent.withValues(alpha: 0.08),
                child: Text(
                  locale.strings.translatedTag,
                  textAlign: TextAlign.center,
                  style: locale.getTextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent.withValues(alpha: 0.7),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            Expanded(
              child: Consumer<AudioProvider>(
                builder: (context, liveAudio, _) {
                  return _buildLyricsContent(liveAudio, locale, track);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(LocaleProvider locale, Track track) {
    final strings = locale.strings;
    final isActive = _showTranslation && _translatedLines != null;
    final isLoading = _isTranslating || _isDownloadingModel;

    return TapScale(
      semanticLabel: isActive ? strings.a11yHideTranslation : strings.a11yTranslate,
      onTap: isLoading ? null : () => _onTranslateTap(locale, track),
      scaleDown: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.bgHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.border,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.accent,
                ),
              )
            : Text(
                strings.translateButton,
                style: locale.getTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
      ),
    );
  }

  Future<void> _onTranslateTap(LocaleProvider locale, Track track) async {
    if (_showTranslation && _translatedLines != null) {
      setState(() => _showTranslation = false);
      return;
    }

    if (_lastTranslatedTrackId == track.id && _translatedLines != null) {
      setState(() => _showTranslation = true);
      return;
    }

    final service = TranslationService();
    final targetLang = locale.currentLanguage;

    final needed = await service.requiredModels(targetLang: targetLang);
    if (needed.isNotEmpty && mounted) {
      final confirmed = await _showDownloadDialog(locale, needed.length);
      if (!confirmed || !mounted) return;

      setState(() => _isDownloadingModel = true);
      try {
        await service.downloadRequiredModels(targetLang: targetLang);
      } catch (e) {
        debugPrint('[Translation] Model download failed: $e');
        if (mounted) {
          setState(() => _isDownloadingModel = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locale.strings.translationError),
              backgroundColor: AppColors.bgCard,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _isDownloadingModel = false);
    }

    setState(() => _isTranslating = true);

    try {
      final lines = _lyrics!.isSynced
          ? _lyrics!.lines.map((l) => l.text).toList()
          : _lyrics!.plainLyrics.split('\n');

      final translated = await service.translateLines(
        lines: lines,
        trackId: track.id,
        targetLang: targetLang,
      );

      if (mounted && _lastLoadedTrackId == track.id) {
        setState(() {
          _translatedLines = translated;
          _lastTranslatedTrackId = track.id;
          _showTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('[Translation] Error: $e');
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale.strings.translationError),
            backgroundColor: AppColors.bgCard,
          ),
        );
      }
    }
  }

  Future<bool> _showDownloadDialog(LocaleProvider locale, int modelCount) async {
    final strings = locale.strings;
    final size = (modelCount * 30).toString();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.borderGlow.withValues(alpha: 0.5)),
            ),
            title: Row(
              children: [
                Icon(Icons.download_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.downloadModelTitle,
                    style: locale.getTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              strings.downloadModelDesc(size),
              style: locale.getTextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  strings.cancel,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  strings.downloadModelConfirm,
                  style: locale.getTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildLyricsContent(AudioProvider audio, LocaleProvider locale, Track track) {
    final strings = locale.strings;
    if (_isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              locale.strings.lyricsLoading,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subtitles_off_outlined,
                color: AppColors.textMuted, size: 36, semanticLabel: strings.a11yNoLyrics),
            const SizedBox(height: 10),
            Text(
              locale.strings.noLyricsFound,
              style: locale.getTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: locale.strings.a11yRetryLyrics,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _lastLoadedTrackId = null;
                _loadLyricsForTrack(track);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.bgHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14, color: AppColors.accent, semanticLabel: strings.a11yRetryLyrics),
                    const SizedBox(width: 6),
                    Text(
                      strings.lyricsRetry,
                      style: locale.getTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      );
    }

    if (_lyrics!.isInstrumental) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: AppColors.accent, size: 40, semanticLabel: strings.a11yVisualizer),
            const SizedBox(height: 12),
            Text(
              locale.strings.instrumentalTrack,
              style: locale.getTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics!.isSynced && _lyrics!.lines.isNotEmpty) {
      final position = audio.position;
      final activeIndex = _lyrics!.activeIndexAt(position);

      final bool isFirstScroll = _lastActiveLyricIndex == -1;
      if (activeIndex != _lastActiveLyricIndex && activeIndex >= 0) {
        _lastActiveLyricIndex = activeIndex;
        if (!_userInteracting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToActiveLine(activeIndex, immediate: isFirstScroll);
            }
          });
        }
      }

      return Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                _userInteracting = true;
                _resumeAutoScrollTimer?.cancel();
                _resumeAutoScrollTimer =
                    Timer(const Duration(milliseconds: 3000), () {
                  if (mounted) {
                    setState(() => _userInteracting = false);
                    _scrollToActiveLine(_lastActiveLyricIndex);
                  }
                });
              }
              return false;
            },
            child: ListView.builder(
              controller: _lyricsScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: _lyrics!.lines.length,
              itemBuilder: (context, i) {
                final line = _lyrics!.lines[i];
                final isActive = i == activeIndex;
                final key = _lineKeys.putIfAbsent(i, () => GlobalKey());

                return GestureDetector(
                  key: key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    audio.seek(line.time);
                    _userInteracting = false;
                    _resumeAutoScrollTimer?.cancel();
                    _scrollToActiveLine(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line.text,
                          textAlign: TextAlign.center,
                          style: locale.getTextStyle(
                            fontSize: isActive ? 17 : 13,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive
                                ? AppColors.accent
                                : AppColors.textPrimary.withValues(alpha: 0.4),
                            shadows: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.7),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        if (_showTranslation &&
                            _translatedLines != null &&
                            i < _translatedLines!.length &&
                            _translatedLines![i].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _translatedLines![i],
                              textAlign: TextAlign.center,
                              style: locale.getTextStyle(
                                fontSize: isActive ? 13 : 11,
                                fontWeight: FontWeight.w400,
                                color: isActive
                                    ? AppColors.textPrimary.withValues(alpha: 0.7)
                                    : AppColors.textMuted.withValues(alpha: 0.5),
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_userInteracting && activeIndex >= 0)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _userInteracting = false);
                    _resumeAutoScrollTimer?.cancel();
                    _scrollToActiveLine(activeIndex);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync,
                            size: 13, color: AppColors.accent, semanticLabel: strings.a11ySyncingLyrics),
                        const SizedBox(width: 6),
                        Text(
                          strings.lyricsFollowing,
                          style: locale.getTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_showTranslation && _translatedLines != null) {
      final plainLines = _lyrics!.plainLyrics.split('\n');
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            for (int i = 0; i < plainLines.length; i++) ...[
              Text(
                plainLines[i],
                textAlign: TextAlign.center,
                style: locale.getTextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
              if (i < _translatedLines!.length && _translatedLines![i].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _translatedLines![i],
                    textAlign: TextAlign.center,
                    style: locale.getTextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        _lyrics!.plainLyrics,
        textAlign: TextAlign.center,
        style: locale.getTextStyle(
          fontSize: 13,
          height: 1.8,
          color: AppColors.textPrimary.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _scrollToActiveLine(int index, {bool immediate = false}) {
    if (index < 0 || _lyrics == null || index >= _lyrics!.lines.length) return;
    if (!_lyricsScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lyricsScrollController.hasClients) {
          _scrollToActiveLine(index, immediate: immediate);
        }
      });
      return;
    }

    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: immediate ? Duration.zero : const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.35,
      );
      return;
    }

    // Line context not yet mounted (off-screen beyond cacheExtent).
    // Estimate target offset and jump/animate controller so item is built.
    final double viewport = _lyricsScrollController.position.hasViewportDimension
        ? _lyricsScrollController.position.viewportDimension
        : 300.0;
    final double estimatedOffset = (index * 54.0 - (viewport * 0.35)).clamp(
      0.0,
      _lyricsScrollController.position.maxScrollExtent > 0
          ? _lyricsScrollController.position.maxScrollExtent
          : (index * 54.0),
    );

    if (immediate) {
      _lyricsScrollController.jumpTo(estimatedOffset);
    } else {
      _lyricsScrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final retryKey = _lineKeys[index];
      if (retryKey?.currentContext != null) {
        Scrollable.ensureVisible(
          retryKey!.currentContext!,
          duration: immediate ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: 0.35,
        );
      }
    });
  }
}

class _TitleMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TitleMarquee({required this.text, required this.style});

  @override
  State<_TitleMarquee> createState() => _TitleMarqueeState();
}

class _TitleMarqueeState extends State<_TitleMarquee> {
  late final ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
  }

  @override
  void didUpdateWidget(_TitleMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _isScrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startMarqueeLoop() async {
    if (!mounted || _isScrolling) return;
    _isScrolling = true;

    while (mounted && _isScrolling) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      final duration = Duration(
        milliseconds: (maxScroll * 40).clamp(1200, 6000).toInt(),
      );
      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );

      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
