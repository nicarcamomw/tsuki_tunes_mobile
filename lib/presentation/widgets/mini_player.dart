import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/track.dart';
import '../navigation/routes.dart';
import '../screens/expanded_player_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/cover_colors.dart';
import '../state/locale_provider.dart';
import 'app_snack.dart';
import 'audio_progress_selector.dart';
import 'haptics.dart';
import 'listened_undo.dart';
import 'oni_mask_icon.dart';
import 'player_art_hero.dart';
import 'player_tint.dart';
import 'queue_panel.dart';
import 'swipeable_sheet.dart';
import 'tap_scale.dart';

/// [tint] for an icon on the dock's dark glass: as it is when it reads at
/// 3:1, else lifted toward white until it does (a dark cover's navy).
Color iconTint(Color tint) =>
    contrastRatio(tint.withValues(alpha: 1), AppColors.bgDeep) >= 3 ? tint : readableTint(tint, ratio: 3);

/// The song playing, at the top of the dock (E-05: it shares the tabs'
/// glass; its progress is the dock's lit top edge).
///
/// - Tap, or swipe up (the row lifts with the finger), to open the player.
/// - Swipe sideways to change songs: the one it goes to shows on its side,
///   by name ("from the start" when "previous" would replay this one).
/// - Swipe down, or the ✕, to stop: "Playback stopped · Undo" brings the
///   song, its queue and its place back.
/// - Hold for the album, the artist and the queue.
///
/// Colours from the cover are lifted where they'd be too dark to read; only
/// the title scrolls when it doesn't fit. TalkBack has open, next, previous
/// and stop as actions.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> with SingleTickerProviderStateMixin {
  // How far the row is swiped sideways, and lifted (negative, towards the
  // player) or pulled down (towards stopping). Only what moves listens:
  // following the finger doesn't rebuild the cover, the title and the
  // buttons every frame.
  final ValueNotifier<double> _swipe = ValueNotifier(0);
  final ValueNotifier<double> _lift = ValueNotifier(0);
  double get _swipeDx => _swipe.value;
  double get _liftDy => _lift.value;
  bool _swipeLocked = false;
  bool _hapticFired = false;
  int _skipDirection = 1;
  late final AnimationController _springCtrl;

  static const _spring = SpringDescription(mass: 1, stiffness: 500, damping: 28);

  /// How far up opens the player, and how far down stops.
  static const double _openLift = 36;
  static const double _dismissPull = 28;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController.unbounded(vsync: this, value: 0)
      ..addListener(() => _swipe.value = _springCtrl.value);
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    _swipe.dispose();
    _lift.dispose();
    super.dispose();
  }

  double get _swipeThreshold {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.2).clamp(70.0, 120.0);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_swipeLocked) return;
    _swipe.value = (_swipeDx + details.delta.dx).clamp(-160.0, 160.0);
    if (!_hapticFired && _swipeDx.abs() > _swipeThreshold) {
      _hapticFired = true;
      Haptics.threshold();
    } else if (_hapticFired && _swipeDx.abs() < _swipeThreshold * 0.6) {
      _hapticFired = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, AudioProvider audio) {
    if (_swipeLocked) return;
    final velocity = details.primaryVelocity ?? 0;
    final hasQueue = audio.queue.length > 1;
    final fastSwipe = velocity.abs() > 700;
    final farSwipe = _swipeDx.abs() > _swipeThreshold;
    if (hasQueue && !audio.isBuffering && (fastSwipe || farSwipe)) {
      final goNext = fastSwipe ? velocity < 0 : _swipeDx < 0;
      _skipDirection = goNext ? 1 : -1;
      _swipeLocked = true;
      Haptics.confirm();
      unawaited(goNext ? audio.next() : audio.previous());
    }
    _hapticFired = false;
    _springCtrl.animateWith(SpringSimulation(_spring, _swipeDx, 0, velocity)).whenComplete(() => _swipeLocked = false);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _lift.value = (_liftDy + details.delta.dy * 0.5).clamp(-_openLift * 1.4, _dismissPull * 1.3);
  }

  void _onVerticalDragEnd(DragEndDetails details, AudioProvider audio) {
    final v = details.primaryVelocity ?? 0;
    if (_liftDy <= -_openLift || v < -300) {
      Haptics.tap();
      _openExpandedPlayer(context);
    } else if (_liftDy >= _dismissPull || v > 700) {
      unawaited(_stopWithUndo(audio));
      return;
    }
    _lift.value = 0;
  }

  /// Stops, and offers to bring it all back: the song, its queue and where
  /// it was. The ✕ sits by play, and one tap too many shouldn't lose that.
  Future<void> _stopWithUndo(AudioProvider audio) async {
    final track = audio.currentTrack;
    if (track == null) return;
    final queue = List<Track>.of(audio.queue);
    final position = audio.position;
    final strings = ref.read(localeProvider).strings;
    // Above the bar once this row has gone.
    final rowHeight = context.size?.height ?? 0;
    final snack = AppSnack.of(context, bottom: (SnackDock.shellHeight - rowHeight).clamp(0.0, double.infinity) + 12);
    Haptics.tap();
    await audio.stop();
    snack.undo(strings.miniStopped, onUndo: () async {
      await audio.playTrack(track, newQueue: queue.isEmpty ? [track] : queue);
      if (position > Duration.zero) await audio.seek(position);
    });
  }

  /// Holding the row: the album, the artist, the queue, above it.
  Future<void> _showOptions(Track track) async {
    Haptics.longPress();
    final strings = ref.read(localeProvider).strings;
    final locale = ref.read(localeProvider);
    final box = context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);
    final options = [
      if (track.albumId.isNotEmpty) (0, Icons.album_rounded, strings.miniGoAlbum),
      if (track.artistId.isNotEmpty) (1, Icons.person_rounded, strings.miniGoArtist),
      (2, Icons.queue_music_rounded, strings.miniQueue),
    ];
    // Above the row: a menu goes down from its top unless it doesn't fit.
    final top = rect.top - 8 - (options.length * 48 + 16);
    final chosen = await showMenu<int>(
      context: context,
      useRootNavigator: true,
      color: AppColors.surfaceRaised,
      // Lifted by its rim, not a heavy shadow.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderGlow),
      ),
      position: RelativeRect.fromLTRB(
          rect.left + AppSpacing.page, top, screen.width - rect.left - AppSpacing.page - 1, screen.height - top),
      items: [
        for (final (i, icon, label) in options)
          PopupMenuItem(
            value: i,
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accentText),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: locale.getTextStyle(fontSize: AppFontSize.bodyLg, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    Haptics.selection();
    switch (chosen) {
      case 0:
        unawaited(AlbumRoute(id: track.albumId).push(context));
      case 1:
        unawaited(ArtistRoute(id: track.artistId).push(context));
      default:
        final height = MediaQuery.sizeOf(context).height * 0.8;
        unawaited(showAppSheet<void>(
          context: context,
          drawHandle: true,
          builder: (sheet) => SizedBox(height: height, child: QueuePanel(onPlay: () => Navigator.of(sheet).pop())),
        ));
    }
  }

  void _openExpandedPlayer(BuildContext context) {
    NavigationEvents.isPlayerExpanded.value = true;
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            transitionDuration: AppMotion.normal,
            reverseTransitionDuration: AppMotion.normal,
            pageBuilder: (_, __, ___) => const ExpandedPlayerScreen(),
            transitionsBuilder: (_, anim, __, child) {
              final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
              return SlideTransition(
                position: Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(curved),
                child: child,
              );
            },
          ),
        )
        .whenComplete(() => NavigationEvents.isPlayerExpanded.value = false);
  }

  /// The player is tinted by a mask's aura, the chosen colour or the cover
  /// ([playerTintColorProvider]), fading between tracks.
  @override
  Widget build(BuildContext context) => AnimatedPlayerTint(
        color: ref.watch(playerTintColorProvider),
        child: Builder(builder: _buildTinted),
      );

  Widget _buildTinted(BuildContext context) {
    final audio = ref.read(audioProvider);
    final (track, isPlaying, isBuffering, spotifyFallbackActive) = ref.watch(
        audioProvider.select((a) => (a.currentTrack, a.isPlaying, a.isBuffering, a.spotifyFallbackActive)));

    // Only this track's flag: the mini player is always on screen, and the
    // library notifies on every sync and history change.
    final isListened = ref.watch(libraryProvider.select((l) => track != null && l.isTrackListened(track.id)));

    if (track == null) return const SizedBox.shrink();

    final locale = ref.read(localeProvider);
    final strings = locale.strings;
    final coverBackground = ref.watch(playerBackgroundColorProvider);
    // A 30 s preview is said after the artist; tinted when it's a surprise
    // (Spotify connected but falling back), quiet when it's the usual.
    final preview = !ref.watch(playbackSourceProvider.select((s) => s.isFullSong));
    final hasQueue = audio.queue.length > 1;
    // The colour isn't read here: it fades between songs (a frame at a
    // time), and only what's painted in it should follow, not the whole row.

    return Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      onTapHint: strings.a11yOpenPlayer,
      onLongPressHint: strings.miniHoldHint,
      customSemanticsActions: {
        CustomSemanticsAction(label: strings.a11yOpenPlayer): () => _openExpandedPlayer(context),
        if (hasQueue) CustomSemanticsAction(label: strings.a11yNext): audio.next,
        if (hasQueue) CustomSemanticsAction(label: strings.a11yPrevious): audio.previous,
        CustomSemanticsAction(label: strings.a11yStop): () => unawaited(_stopWithUndo(audio)),
      },
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            Haptics.tap();
            _openExpandedPlayer(context);
          },
          onLongPress: () => unawaited(_showOptions(track)),
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: (d) => _onVerticalDragEnd(d, audio),
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, audio),
          // On the dock's glass: the cover's colour seeps in from the
          // artwork's side.
          child: ValueListenableBuilder<double>(
            valueListenable: _lift,
            builder: (context, dy, child) => Transform.translate(
              offset: Offset(0, dy),
              // Pulled down towards stopping, the row fades.
              child: Opacity(opacity: 1 - (dy.clamp(0.0, _dismissPull) / _dismissPull) * 0.6, child: child),
            ),
            child: AnimatedContainer(
                duration: AnimatedPlayerTint.duration,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [(coverBackground ?? AppColors.surfaceCard).withValues(alpha: 0.7), Colors.transparent],
                    stops: const [0.0, 0.7],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The dock's lit top edge, clear of its round corners.
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppRadius.sheet),
                      child: _MiniProgressBar(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          // --- Track info (swipeable) ---
                          Expanded(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _swipe,
                              builder: (context, dx, child) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  // The song a swipe goes to, on its side.
                                  if (hasQueue && dx != 0)
                                    Positioned.fill(
                                      child: _SwipeHint(
                                        dx: dx,
                                        threshold: _swipeThreshold,
                                        target: dx < 0 ? audio.nextPreview : audio.previousPreview,
                                        fromStart: strings.miniFromStart,
                                        locale: locale,
                                      ),
                                    ),
                                  Transform.translate(
                                    offset: Offset(dx * 0.3, 0),
                                    // Opacity at 1.0 adds no layer.
                                    child: Opacity(
                                      opacity: 1.0 - (1.0 - (1 - (dx.abs() / 200)).clamp(0.3, 1.0)) * 0.7,
                                      child: child,
                                    ),
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                      duration: AppMotion.normal,
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        final entering = child.key == ValueKey(track.id);
                                        final dx = _skipDirection * (entering ? 0.15 : -0.15);
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Row(
                                        key: ValueKey(track.id),
                                        children: [
                                          // Its own layer: the breathing
                                          // repaints the cover, not the dock.
                                          RepaintBoundary(
                                            child: _BreathingCover(
                                              trackId: track.id,
                                              coverUrl: track.coverUrl,
                                              isPlaying: isPlaying,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _MarqueeText(
                                                  text: track.title,
                                                  style: locale.getTextStyle(
                                                    fontSize: AppFontSize.title,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textBright,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                // One line moves at a time:
                                                // the artist ends in "…".
                                                Builder(
                                                  builder: (context) => Text(
                                                    preview
                                                        ? '${track.fullArtistName}  ·  ${strings.sourcePreviewShort}'
                                                        : track.fullArtistName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: locale.getTextStyle(
                                                      fontSize: AppFontSize.body,
                                                      color: spotifyFallbackActive
                                                          ? PlayerTint.textOf(context)
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // --- Oni mask (listened toggle) ---
                          // Guests have no listened marks (they need an account).
                          if (!ref.watch(authProvider.select((a) => a.isGuest))) ...[
                            Tooltip(
                              message: isListened ? strings.unmarkAsListened : strings.markAsListened,
                              child: TapScale(
                                semanticLabel: isListened ? strings.unmarkAsListened : strings.markAsListened,
                                onTap: () => unawaited(toggleListenedWithUndo(context, ref, track)),
                                scaleDown: 0.8,
                                child: OniMaskIcon(isActive: isListened, size: 20),
                              ),
                            ),
                          ],
                          // --- Play / Pause ---
                          // The icon turns between play and pause; loading,
                          // a ring runs around it instead of hiding it.
                          TapScale(
                            semanticLabel: isPlaying ? strings.a11yPause : strings.a11yPlay,
                            onTap: isBuffering ? null : audio.togglePlay,
                            scaleDown: 0.85,
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isBuffering)
                                    SizedBox.expand(
                                      child: Builder(
                                        builder: (context) => CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          valueColor: AlwaysStoppedAnimation<Color>(iconTint(PlayerTint.of(context))),
                                        ),
                                      ),
                                    ),
                                  AnimatedSwitcher(
                                    duration: AppMotion.fast,
                                    switchInCurve: Curves.easeOutBack,
                                    transitionBuilder: (child, a) => RotationTransition(
                                      turns: Tween(begin: -0.12, end: 0.0).animate(a),
                                      child: ScaleTransition(scale: a, child: child),
                                    ),
                                    // Only the icon follows the colour's fade.
                                    child: Builder(
                                      key: ValueKey(isPlaying),
                                      builder: (context) => Icon(
                                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                        size: isBuffering ? 26 : 32,
                                        color: iconTint(PlayerTint.of(context)).withValues(alpha: isBuffering ? 0.5 : 1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // --- Close / Stop (undoable) ---
                          TapScale(
                            semanticLabel: strings.a11yStop,
                            onTap: () => unawaited(_stopWithUndo(audio)),
                            scaleDown: 0.85,
                            child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breathing cover art
// ---------------------------------------------------------------------------

class _BreathingCover extends StatefulWidget {
  final String trackId;
  final String coverUrl;
  final bool isPlaying;

  const _BreathingCover({
    required this.trackId,
    required this.coverUrl,
    required this.isPlaying,
  });

  @override
  State<_BreathingCover> createState() => _BreathingCoverState();
}

class _BreathingCoverState extends State<_BreathingCover>
    with SingleTickerProviderStateMixin {
  // 120 fps: a breath forever would redraw the dock (and its blur) every
  // frame while music plays. It breathes twice when a song starts playing,
  // then rests lit.
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.breath);
  bool _reduceMotion = false;

  /// Two breaths: in and out, twice (each count is one way).
  static const _breaths = 4;

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _breathe();
  }

  void _breathe() {
    if (_reduceMotion) return;
    _controller.value = 0;
    unawaited(_controller.repeat(reverse: true, count: _breaths));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _controller.isAnimating) _controller.stop();
  }

  @override
  void didUpdateWidget(_BreathingCover old) {
    super.didUpdateWidget(old);
    final started = widget.isPlaying && (!old.isPlaying || widget.trackId != old.trackId);
    if (started) {
      _breathe();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // At rest (playing, breaths done) it stays half lit.
        final t = widget.isPlaying ? (_controller.isAnimating ? _controller.value : 0.5) : 0.0;
        final glowAlpha = 0.15 + 0.35 * t;
        final borderAlpha = 0.3 + 0.7 * t;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: PlayerTint.of(context).withValues(alpha: borderAlpha),
              width: 1.5,
            ),
            boxShadow: widget.isPlaying
                ? [
                    // One blur size: only its light changes as it breathes.
                    BoxShadow(
                      color: PlayerTint.of(context).withValues(alpha: glowAlpha),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: PlayerArtHero(
        trackId: widget.trackId,
        coverUrl: widget.coverUrl,
        isPlaying: widget.isPlaying,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: SizedBox(
              width: 44,
              height: 44,
              child: widget.coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                    memCacheWidth: imageCacheSize(context, (44).toDouble()),
                      imageUrl: widget.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.bgMid),
                      errorWidget: (_, __, ___) => const _NoCover(),
                    )
                  : const _NoCover(),
            ),
          ),
        ),
      ),
    );
  }
}

/// No cover: a note in the player's colour (it alone follows the colour's
/// fade, not the cover around it).
class _NoCover extends StatelessWidget {
  const _NoCover();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.bgMid,
        child: Center(child: Icon(Icons.music_note_rounded, color: PlayerTint.of(context))),
      );
}

// ---------------------------------------------------------------------------
// Marquee text — AnimationController-driven (no async while-loop)
// ---------------------------------------------------------------------------

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

/// A title too long for its room glides across once, rests, and comes back
/// (120 fps: frames only while it moves, none during the rests). Its edges
/// fade while it doesn't fit.
class _MarqueeTextState extends State<_MarqueeText> {
  final ScrollController _scroll = ScrollController();
  // The scroller keeps its element when the fade comes and goes (one
  // scroll position, never two).
  final GlobalKey _scrollerKey = GlobalKey();
  Timer? _next;
  bool _overflows = false;
  bool _reduceMotion = false;

  /// Before the first glide, and between glides.
  static const Duration _firstRest = Duration(milliseconds: 1800);
  static const Duration _rest = Duration(seconds: 10);
  static const Duration _atEnd = Duration(milliseconds: 1600);
  static const Duration _back = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _next?.cancel();
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text || widget.style != old.style) {
      _next?.cancel();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted || !_scroll.hasClients) return;
    final overflows = _scroll.position.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    _next?.cancel();
    if (overflows && !_reduceMotion) _next = Timer(_firstRest, _glide);
  }

  Future<void> _glide() async {
    if (!mounted || !_scroll.hasClients || _reduceMotion) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    // About 25 px a second: read as it goes.
    // As long as reading it takes (a reading time, not a motion token).
    final across = Duration(milliseconds: (max * 40).clamp(1200.0, 6000.0).round());
    await _scroll.animateTo(max, duration: across, curve: Curves.linear);
    if (!mounted) return;
    _next = Timer(_atEnd, () async {
      if (!mounted || !_scroll.hasClients) return;
      await _scroll.animateTo(0, duration: _back, curve: Curves.easeOutCubic);
      if (mounted) _next = Timer(_rest, _glide);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scroller = SingleChildScrollView(
      key: _scrollerKey,
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
    // A fitting title needs no fade, and no layer for one.
    if (!_overflows) return scroller;
    bool scrolled() => _scroll.hasClients && _scroll.positions.length == 1 && _scroll.offset > 0;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [scrolled() ? Colors.transparent : Colors.white, Colors.white, Colors.white, Colors.transparent],
        stops: const [0, 0.08, 0.88, 1],
      ).createShader(bounds),
      child: scroller,
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

/// The song's progress as the dock's lit top edge: the played part glows
/// in the player's colour, with a brighter point at its head.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context) {
    final tint = PlayerTint.of(context);
    return AudioProgressSelector<double>(
      selector: (a) {
        final total = a.duration.inMilliseconds;
        if (total <= 0) return 0.0;
        return (a.position.inMilliseconds / total).clamp(0.0, 1.0);
      },
      builder: (context, progress) => Semantics(
        // The player's own bar is the one to read and move.
        excludeSemantics: true,
        child: SizedBox(
          height: 2.5,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.55), blurRadius: 6)],
                  ),
                  child: progress <= 0
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: tint, blurRadius: 6)],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe hint
// ---------------------------------------------------------------------------

/// While the row is dragged sideways: the song it goes to, on the side it
/// comes from (its name, or "from the start" when "previous" would replay
/// this one), brighter as the swipe nears its threshold.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.dx,
    required this.threshold,
    required this.target,
    required this.fromStart,
    required this.locale,
  });

  final double dx;
  final double threshold;
  final Track? target;
  final String fromStart;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    final reach = (dx.abs() / threshold).clamp(0.0, 1.0);
    final next = dx < 0;
    final lit = reach >= 1;
    final color = lit ? PlayerTint.textOf(context) : AppColors.textSecondary;
    final icon = Icon(
      next ? Icons.skip_next_rounded : (target == null ? Icons.replay_rounded : Icons.skip_previous_rounded),
      size: 22,
      color: lit ? iconTint(PlayerTint.of(context)) : AppColors.textMuted,
    );
    final label = Flexible(
      child: Text(
        target?.title ?? (next ? '' : fromStart),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: next ? TextAlign.right : TextAlign.left,
        style: locale.getTextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w700, color: color),
      ),
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: reach,
          child: FractionallySizedBox(
            // The side the row left open.
            widthFactor: 0.55,
            alignment: next ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: next ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: next ? [label, const SizedBox(width: 6), icon] : [icon, const SizedBox(width: 6), label],
            ),
          ),
        ),
      ),
    );
  }
}
