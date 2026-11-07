import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../navigation/app_router.dart';
import '../navigation/routes.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/locale_provider.dart';
import '../state/use_cases.dart';
import '../widgets/ambient_mixer_sheet.dart';
import '../widgets/audio_progress_selector.dart';
import '../widgets/eco_widgets.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/oni_mask_colors.dart';
import '../widgets/oni_mask_icon.dart';
import '../widgets/playback_error_text.dart';
import '../widgets/player_tint.dart';
import '../widgets/playlist_selector_sheet.dart';
import '../widgets/queue_panel.dart';
import '../widgets/radio_control_sheet.dart';
import '../widgets/rinnegan_visualizer.dart';
import '../widgets/shuffle_mode_icon.dart';
import '../widgets/smart_shuffle_sheet.dart';
import '../widgets/tap_scale.dart';
import '../widgets/track_tile.dart';
import 'lyrics_screen.dart';
import 'main_navigation_screen.dart';

part 'expanded_player/player_controls.dart';
part 'expanded_player/player_sheets.dart';
part 'expanded_player/player_widgets.dart';
part 'expanded_player/queue_panel.dart';

enum _CenterViewMode { artwork, queue }

// How much of the lyrics card peeks below the player, hinting it's there.
const double _kLyricsPeek = 44;

class ExpandedPlayerScreen extends ConsumerStatefulWidget {
  const ExpandedPlayerScreen({super.key});

  @override
  ConsumerState<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends ConsumerState<ExpandedPlayerScreen>
    with SingleTickerProviderStateMixin {
  double _dragDy = 0;
  bool _reduceMotion = false;
  _CenterViewMode _viewMode = _CenterViewMode.artwork;
  late final AnimationController _snapBack;
  late Animation<double> _snapAnimation;

  final LyricsController _lyrics = LyricsController();

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

  /// Keeps the lyrics in step with the playing track.
  void _syncLyrics(Track track) {
    if (_lyrics.trackId != track.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lyrics.ensureFor(track);
      });
    }
  }

  void _openLyrics() {
    if (!ecoAllows(context, EcoFeature.lyrics)) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      LyricsScreen.route(controller: _lyrics),
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
      final album = Album(
        id: track.albumId,
        title: track.albumTitle.isNotEmpty ? track.albumTitle : ref.read(stringsProvider).unknownAlbum,
        coverUrl: track.coverUrl,
        artistId: track.artistId,
        artistName: track.artistName,
      );
      AlbumRoute(id: album.id, $extra: album).push(rootNavigatorKey.currentContext!);
    } else if (track.artistId.isNotEmpty) {
      Navigator.of(context).pop();
      _openArtistOf(track);
    }
  }

  void _collapse() {
    NavigationEvents.isPlayerExpanded.value = false;
    Navigator.of(context).pop();
  }

  /// An equipped UL or DS mask tints the player with its aura.
  @override
  Widget build(BuildContext context) {
    // A UL or DS being's aura, else the colour the levels opened and the
    // user chose, else the app's red.
    final aura = ref.watch(maskProvider.select((m) =>
        m.equipped?.playerAura ?? (m.playerColor == null ? null : Color(m.playerColor!.argb))));
    return PlayerTint(color: aura ?? AppColors.accent, child: Builder(builder: _buildTinted));
  }

  Widget _buildTinted(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final audio = ref.read(audioProvider);
    final (track, isPlaying, isBuffering, shuffleMode, repeatMode, useSpotify, radioActive, playbackError) =
        ref.watch(audioProvider.select(
            (a) => (a.currentTrack, a.isPlaying, a.isBuffering, a.shuffleMode, a.repeatMode, a.useSpotify, a.isRadioActive, a.lastPlaybackError)));
    // Only this track's listened flag: watching the whole library would rebuild
    // the player on every sync and history update.
    final isListened = ref.watch(libraryProvider.select(
        (l) => track != null && l.isTrackListened(track.id)));

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
              onPressed: _collapse,
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
                  _buildTopBar(track, locale, radioActive: radioActive),

                  // Art or Queue (lyrics live in a card below the player)
                  if (_viewMode == _CenterViewMode.queue)
                    _QueueView(
                      audio: audio,
                      locale: locale,
                      onPlay: () =>
                          setState(() => _viewMode = _CenterViewMode.artwork),
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
                        fullSong: !ref.watch(audioProvider.select((a) => a.canChangeTempo)),
                        position: () => audio.position,
                        speed: () => audio.playbackSpeed,
                      ),
                    ),
                    ),
                    const SizedBox(height: 24),
                    const Spacer(),
                  ],

                _buildTrackInfo(track, locale, isListened: isListened),

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

                _PlayerControls(
                  audio: audio,
                  locale: locale,
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  shuffleMode: shuffleMode,
                  repeatMode: repeatMode,
                ),

                const SizedBox(height: 12),

                // Device tag + Sleep Timer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AmbientButton(locale: locale),
                      Text(
                        useSpotify ? 'SPOTIFY CONNECT' : 'DEEZER PREVIEW',
                        style: locale.getTextStyle(
                          fontSize: 9,
                          color: PlayerTint.of(context),
                          letterSpacing: 2,
                        ),
                      ),
                      _SleepTimerButton(audio: audio, locale: locale),
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

  /// Symmetric: collapse chevron | where it's playing from | song menu.
  Widget _buildTopBar(Track track, LocaleProvider locale,
      {required bool radioActive}) {
    final strings = locale.strings;
    return Padding(
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
              onPressed: _collapse,
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
                        color: PlayerTint.of(context),
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
                  context, track, locale,
                  radioActive: radioActive,
                  onShowQueue: () =>
                      setState(() => _viewMode = _CenterViewMode.queue),
                  onOpenLyrics: _openLyrics,
                  onOpenAlbum: () => _navigateToSource(context, track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Title, artist (opens their page) and the listened mask.
  Widget _buildTrackInfo(Track track, LocaleProvider locale,
      {required bool isListened}) {
    final strings = locale.strings;
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
                      _openArtistOf(track);
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
          // Guests have no listened marks (they need an account).
          if (!ref.watch(authProvider.select((a) => a.isGuest)))
            TapScale(
              semanticLabel: isListened ? strings.a11yUnmarkListened : strings.a11yMarkListened,
              onTap: () => ref.read(toggleTrackListenedProvider)(track),
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

}
