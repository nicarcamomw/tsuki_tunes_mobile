import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/cyber_page_route.dart';
import '../core/utils/image_cache_size.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/ambient_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../services/bpm_flow.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/audio_progress_selector.dart';
import '../widgets/flow_sheet.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/radio_control_sheet.dart';
import '../widgets/rinnegan_visualizer.dart';
import '../widgets/tap_scale.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'lyrics_screen.dart';
import 'main_navigation_screen.dart';

enum _CenterViewMode { artwork, queue }

// How much of the lyrics card peeks below the player, hinting it's there.
const double _kLyricsPeek = 44;

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

  final LyricsController _lyrics = LyricsController();
  Color _tint = AlbumTint.fallback;
  String? _tintUrl;

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
    _lyrics.dispose();
    super.dispose();
  }

  /// Keeps the lyrics and the album color in step with the playing track.
  void _syncLyrics(Track track) {
    if (_lyrics.trackId != track.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lyrics.ensureFor(track);
      });
    }
    if (_tintUrl != track.coverUrl) {
      _tintUrl = track.coverUrl;
      final cached = AlbumTint.cached(track.coverUrl);
      if (cached != null) {
        _tint = cached;
      } else {
        AlbumTint.of(track.coverUrl).then((c) {
          if (mounted && _tintUrl == track.coverUrl) setState(() => _tint = c);
        });
      }
    }
  }

  void _openLyrics() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      LyricsScreen.route(controller: _lyrics, tint: _tint),
    );
  }

  /// Pulling down at the top of the page drags the player away, like the
  /// rest of the screen; scrolling down reveals the lyrics card.
  bool _onPageScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _snapBack.stop();
      setState(() => _dragDy = (_dragDy - n.overscroll * 0.6).clamp(0, 400));
    } else if (n is ScrollEndNotification && _dragDy > 0) {
      _onVerticalDragEnd(
        DragEndDetails(primaryVelocity: n.dragDetails?.primaryVelocity ?? 0),
      );
    }
    return false;
  }

  Widget _centerPage(Track track, Widget player) =>
      _viewMode == _CenterViewMode.artwork
          ? _withLyricsBelow(track, player)
          : player;

  /// The player fills the screen with the lyrics card peeking below it.
  Widget _withLyricsBelow(Track track, Widget player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        return NotificationListener<ScrollNotification>(
          onNotification: _onPageScroll,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight - _kLyricsPeek,
                  child: player,
                ),
                LyricsCard(
                  controller: _lyrics,
                  track: track,
                  tint: _tint,
                  onOpen: _openLyrics,
                ),
                SizedBox(height: 24 + bottom),
              ],
            ),
          ),
        );
      },
    );
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
        CyberPageRoute(
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
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final strings = locale.strings;
    final audio = context.read<AudioProvider>();
    final (track, isPlaying, isBuffering, isShuffle, repeatMode, useSpotify, radioActive, playbackError) =
        context.select<AudioProvider, (Track?, bool, bool, bool, PlaybackRepeatMode, bool, bool, PlaybackError?)>(
            (a) => (a.currentTrack, a.isPlaying, a.isBuffering, a.isShuffle, a.repeatMode, a.useSpotify, a.isRadioActive, a.lastPlaybackError));
    // Only this track's listened flag: watching the whole library would rebuild
    // the player on every sync and history update.
    final isListened = context.select<LibraryProvider, bool>(
        (l) => track != null && l.isTrackListened(track.id));

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

    final library = context.read<LibraryProvider>();
    _syncLyrics(track);

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
              child: _centerPage(track, Column(
                children: [
                  // Top bar — symmetric: chevron | centered source | menu
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: IconButton(
                            tooltip: strings.a11yCollapsePlayer,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                size: 30, color: AppColors.textPrimary),
                            onPressed: () {
                              NavigationEvents.isPlayerExpanded.value = false;
                              Navigator.of(context).pop();
                            },
                          ),
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
                                  Text(
                                    strings.playingFrom,
                                    style: locale.getTextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                      letterSpacing: 2.0,
                                    ),
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
                        SizedBox(
                          width: 48,
                          child: IconButton(
                            tooltip: strings.a11yQueue,
                            icon: const Icon(Icons.more_vert,
                                size: 24, color: AppColors.textPrimary),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _showSongOptionsSheet(
                                context, audio, track, locale,
                                radioActive: radioActive,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Art or Queue (lyrics live in a card below the player)
                  if (_viewMode == _CenterViewMode.queue)
                    Selector<AudioProvider, (int, int)>(
                      selector: (_, a) =>
                          (Object.hashAll(a.queue.map((t) => t.id)), a.currentIndex),
                      builder: (context, _, __) => _buildQueueView(audio, locale),
                    )
                  else ...[
                    const Spacer(),
                    ExcludeSemantics(
                    child: Hero(
                      tag: 'player_art_${track.id}',
                      child: RinneganVisualizer(
                        isPlaying: isPlaying,
                        imageUrl: track.coverUrl,
                        size: MediaQuery.of(context).size.width * 0.72,
                        trackId: track.id,
                        fullSong: !context.select<AudioProvider, bool>((a) => a.canChangeTempo),
                        position: () => audio.position,
                        speed: () => audio.playbackSpeed,
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

                // Progress bar — isolated so position ticks don't rebuild
                // the rest of the player.
                _IsolatedProgressBar(locale: locale),

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
                      Builder(builder: (c) => _buildAmbientButton(c, locale)),
                      Text(
                        useSpotify ? 'SPOTIFY CONNECT' : 'DEEZER PREVIEW',
                        style: locale.getTextStyle(
                          fontSize: 9,
                          color: AppColors.accent,
                          letterSpacing: 2,
                        ),
                      ),
                      Builder(builder: (c) => _buildSleepTimerButton(c, audio, locale)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            )),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildAmbientButton(BuildContext context, LocaleProvider locale) {
    final count = context.select<AmbientProvider, int>(
        (a) => a.isPlaying ? a.activeSounds.length : 0);
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

  Widget _buildSleepTimerButton(BuildContext context, AudioProvider audio, LocaleProvider locale) {
    final strings = locale.strings;
    final isActive = context.select<AudioProvider, bool>((a) => a.isSleepTimerActive);
    // Whole seconds: the label shows nothing finer, so no rebuild per tick.
    final remainingSeconds =
        context.select<AudioProvider, int?>((a) => a.sleepTimerRemaining?.inSeconds);
    final remaining = remainingSeconds == null ? null : Duration(seconds: remainingSeconds);

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

  // ── Song options bottom sheet (replaces the old top-bar buttons) ──

  void _showSongOptionsSheet(
    BuildContext context,
    AudioProvider audio,
    Track track,
    LocaleProvider locale, {
    required bool radioActive,
  }) {
    final strings = locale.strings;
    final bpm = BpmService.shared.cached(track.id);
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
                  _songOptionTile(
                    icon: Icons.speed,
                    label: 'BPM',
                    trailing: '${bpm.round()}',
                    locale: locale,
                  ),
                // Queue
                _songOptionTile(
                  icon: Icons.queue_music,
                  label: strings.a11yQueue,
                  locale: locale,
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.selectionClick();
                    setState(() => _viewMode = _CenterViewMode.queue);
                  },
                ),
                // Radio
                _songOptionTile(
                  icon: Icons.sensors,
                  label: radioActive ? strings.radioTune : strings.radioStart,
                  locale: locale,
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
                _songOptionTile(
                  icon: Icons.lyrics_outlined,
                  label: strings.a11yLyrics,
                  locale: locale,
                  onTap: () {
                    Navigator.pop(context);
                    _openLyrics();
                  },
                ),
                // Go to album
                if (track.albumId.isNotEmpty)
                  _songOptionTile(
                    icon: Icons.album,
                    label: track.albumTitle.isNotEmpty
                        ? track.albumTitle
                        : strings.unknownAlbum,
                    locale: locale,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSource(context, track);
                    },
                  ),
                // Go to artist
                if (track.artistId.isNotEmpty)
                  _songOptionTile(
                    icon: Icons.person,
                    label: track.artistName,
                    locale: locale,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pop();
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
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _songOptionTile({
    required IconData icon,
    required String label,
    required LocaleProvider locale,
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
                  if (audio.upcomingTracks.length >= 3) ...[
                    Semantics(
                      button: true,
                      label: strings.flowTitle,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          FlowSheet.show(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.neonCyan.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.show_chart_rounded, size: 13, color: AppColors.neonCyan),
                              const SizedBox(width: 4),
                              Text(
                                strings.flowButton,
                                style: locale.getTextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neonCyan,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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
                      // onReorderItem already adjusts newIndex for the
                      // removed item, unlike the deprecated onReorder.
                      onReorderItem: (oldIndex, newIndex) {
                        audio.reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, i) {
                        final t = queue[i];
                        final isCur = audio.currentTrack?.id == t.id;
                        final queuedByUser = !isCur && audio.isUserQueued(t.id);
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
                                        : queuedByUser
                                        ? Icon(Icons.queue_music,
                                            color: AppColors.neonCyan, size: 16, semanticLabel: strings.queuedByYou)
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
                                            memCacheWidth: imageCacheSize(context, (36).toDouble()),
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
                                          queuedByUser
                                              ? '${strings.queuedByYou} · ${t.fullArtistName}'
                                              : t.fullArtistName,
                                          style: locale.getTextStyle(
                                            color: queuedByUser
                                                ? AppColors.neonCyan.withValues(alpha: 0.85)
                                                : AppColors.textSecondary,
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
                                  if (BpmService.shared.cached(t.id) case final bpm?)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Text(
                                        '${bpm.round()}',
                                        style: locale.getTextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neonCyan.withValues(alpha: 0.8),
                                        ),
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

class _IsolatedProgressBar extends StatelessWidget {
  const _IsolatedProgressBar({required this.locale});

  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    return AudioProgressSelector<(Duration, Duration, Duration)>(
      selector: (a) => (a.position, a.duration, a.bufferedPosition),
      builder: (context, p) => _bar(context, p.$1, p.$2, p.$3),
    );
  }

  Widget _bar(BuildContext context, Duration position, Duration duration, Duration buffered) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ProgressBar(
        progress: position,
        total: duration,
        buffered: buffered,
        onSeek: context.read<AudioProvider>().seek,
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
    );
  }
}

class _PulsingGlowPlay extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  const _PulsingGlowPlay({required this.isPlaying, required this.isBuffering});

  @override
  State<_PulsingGlowPlay> createState() => _PulsingGlowPlayState();
}

class _PulsingGlowPlayState extends State<_PulsingGlowPlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isPlaying) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingGlowPlay old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!widget.isPlaying && _glow.isAnimating) {
      _glow.animateTo(0.0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentGlow,
              blurRadius: 18 + 12 * _glow.value,
              spreadRadius: 2 + 4 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
      child: Center(
        child: widget.isBuffering
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.textBright),
                ),
              )
            : Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: AppColors.textBright,
              ),
      ),
    );
  }
}
