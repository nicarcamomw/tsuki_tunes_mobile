import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../screens/expanded_player_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/cover_colors.dart';
import 'audio_progress_selector.dart';
import 'haptics.dart';
import 'listened_undo.dart';
import 'oni_mask_icon.dart';
import 'player_art_hero.dart';
import 'player_tint.dart';
import 'tap_scale.dart';

/// The song playing, at the top of the dock (E-05: it shares the tabs'
/// glass; its progress is the dock's lit top edge).
///
/// Tap or swipe up to open the player: the row lifts with the finger.
/// Swipe sideways to change songs: the next or previous one shows its icon
/// on the side it comes from. TalkBack has both as actions.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _swipeDx = 0;
  // How far up the row has been lifted (negative), towards the player.
  double _liftDy = 0;
  bool _swipeLocked = false;
  bool _hapticFired = false;
  int _skipDirection = 1;
  late final AnimationController _springCtrl;

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 28,
  );

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController.unbounded(vsync: this, value: 0)
      ..addListener(() => setState(() => _swipeDx = _springCtrl.value));
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  double get _swipeThreshold {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.2).clamp(70.0, 120.0);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_swipeLocked) return;
    setState(() {
      _swipeDx = (_swipeDx + details.delta.dx).clamp(-160.0, 160.0);
      if (!_hapticFired && _swipeDx.abs() > _swipeThreshold) {
        _hapticFired = true;
        Haptics.threshold();
      } else if (_hapticFired && _swipeDx.abs() < _swipeThreshold * 0.6) {
        _hapticFired = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, AudioProvider audio) {
    if (_swipeLocked) return;

    final velocity = details.primaryVelocity ?? 0;
    final hasQueue = audio.queue.length > 1;
    final fastSwipe = velocity.abs() > 700;
    final farSwipe = _swipeDx.abs() > _swipeThreshold;
    final triggered =
        hasQueue && !audio.isBuffering && (fastSwipe || farSwipe);

    if (triggered) {
      final goNext = fastSwipe ? velocity < 0 : _swipeDx < 0;
      _skipDirection = goNext ? 1 : -1;
      _swipeLocked = true;
      Haptics.confirm();
      if (goNext) {
        audio.next();
      } else {
        audio.previous();
      }
    }

    _hapticFired = false;
    _springCtrl
        .animateWith(SpringSimulation(_spring, _swipeDx, 0, velocity))
        .whenComplete(() => _swipeLocked = false);
  }

  /// The lift that opens the player, as a swipe up.
  static const double _openLift = 36;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() => _liftDy = (_liftDy + details.delta.dy * 0.5).clamp(-_openLift * 1.4, 0.0));
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final opens = _liftDy <= -_openLift || (details.primaryVelocity ?? 0) < -300;
    if (opens) {
      Haptics.tap();
      _openExpandedPlayer(context);
    }
    setState(() => _liftDy = 0);
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
              final curved = CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(curved),
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
    final (track, isPlaying, isBuffering, spotifyFallbackActive) =
        ref.watch(audioProvider.select(
            (a) => (a.currentTrack, a.isPlaying, a.isBuffering, a.spotifyFallbackActive)));

    // Only this track's flag: the mini player is always on screen, and the
    // library notifies on every sync and history change.
    final isListened = ref.watch(libraryProvider.select(
        (l) => track != null && l.isTrackListened(track.id)));

    if (track == null) return const SizedBox.shrink();

    final locale = ref.read(localeProvider);
    final coverBackground = ref.watch(playerBackgroundColorProvider);
    final swipeOpacity = (1 - (_swipeDx.abs() / 200)).clamp(0.3, 1.0);
    // A 30 s preview is said after the artist; tinted when it's a surprise
    // (Spotify connected but falling back), quiet when it's the usual.
    final preview = !ref.watch(playbackSourceProvider.select((s) => s.isFullSong));

    final hasQueue = audio.queue.length > 1;
    final threshold = _swipeThreshold;
    final strings = locale.strings;
    return Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      onTapHint: strings.a11yOpenPlayer,
      customSemanticsActions: {
        CustomSemanticsAction(label: strings.a11yOpenPlayer): () => _openExpandedPlayer(context),
        if (hasQueue) CustomSemanticsAction(label: strings.a11yNext): audio.next,
        if (hasQueue) CustomSemanticsAction(label: strings.a11yPrevious): audio.previous,
      },
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () { Haptics.tap(); _openExpandedPlayer(context); },
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, audio),
          // On the dock's glass: the cover's colour seeps in from the
          // artwork's side.
          child: Transform.translate(
            offset: Offset(0, _liftDy),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // --- Track info (swipeable) ---
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // The song a swipe goes to, on its side.
                                if (hasQueue && _swipeDx != 0)
                                  Positioned.fill(
                                    child: _SwipeHint(dx: _swipeDx, threshold: threshold),
                                  ),
                                Transform.translate(
                              offset: Offset(_swipeDx * 0.3, 0),
                              // Opacity at 1.0 adds no layer; the old color
                              // filter forced an offscreen pass every frame.
                              child: Opacity(
                                opacity: 1.0 - (1.0 - swipeOpacity) * 0.7,
                                child: AnimatedSwitcher(
                                  duration: AppMotion.normal,
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    final entering =
                                        child.key == ValueKey(track.id);
                                    final dx = _skipDirection *
                                        (entering ? 0.15 : -0.15);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween(
                                          begin: Offset(dx, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Row(
                                    key: ValueKey(track.id),
                                    children: [
                                      _BreathingCover(
                                        trackId: track.id,
                                        coverUrl: track.coverUrl,
                                        isPlaying: isPlaying,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _MarqueeText(
                                              text: track.title,
                                              style: locale.getTextStyle(
                                                fontSize: AppFontSize.bodyLg,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textBright,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            _MarqueeText(
                                              text: preview
                                                  ? '${track.fullArtistName}  ·  ${locale.strings.sourcePreviewShort}'
                                                  : track.fullArtistName,
                                              style: locale.getTextStyle(
                                                fontSize: AppFontSize.caption,
                                                color: spotifyFallbackActive
                                                    ? PlayerTint.of(context)
                                                        .withValues(alpha: 0.7)
                                                    : AppColors.textSecondary,
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // --- Oni mask (listened toggle) ---
                          // Guests have no listened marks (they need an account).
                          if (!ref.watch(authProvider.select((a) => a.isGuest))) ...[
                            Tooltip(
                              message: isListened
                                  ? locale.strings.unmarkAsListened
                                  : locale.strings.markAsListened,
                              child: TapScale(
                                semanticLabel: isListened
                                    ? locale.strings.unmarkAsListened
                                    : locale.strings.markAsListened,
                                onTap: () =>
                                    unawaited(toggleListenedWithUndo(context, ref, track)),
                                scaleDown: 0.8,
                                child: OniMaskIcon(
                                  isActive: isListened,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                          // --- Play / Pause ---
                          // The icon turns between play and pause; loading,
                          // a ring runs around it instead of hiding it.
                          TapScale(
                            semanticLabel: isPlaying
                                ? locale.strings.a11yPause
                                : locale.strings.a11yPlay,
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        valueColor: AlwaysStoppedAnimation<Color>(PlayerTint.of(context)),
                                      ),
                                    ),
                                  AnimatedSwitcher(
                                    duration: AppMotion.fast,
                                    switchInCurve: Curves.easeOutBack,
                                    transitionBuilder: (child, a) => RotationTransition(
                                      turns: Tween(begin: -0.12, end: 0.0).animate(a),
                                      child: ScaleTransition(scale: a, child: child),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_filled_rounded,
                                      key: ValueKey(isPlaying),
                                      size: isBuffering ? 26 : 32,
                                      color: PlayerTint.of(context).withValues(alpha: isBuffering ? 0.5 : 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // --- Close / Stop ---
                          TapScale(
                            semanticLabel: locale.strings.a11yStop,
                            onTap: () => audio.stop(),
                            scaleDown: 0.85,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textMuted,
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
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.breath,
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion && _controller.isAnimating) _controller.stop();
  }

  @override
  void didUpdateWidget(_BreathingCover old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating && !_reduceMotion) {
      _controller.repeat(reverse: true);
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
        final t = widget.isPlaying ? _controller.value : 0.0;
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
                    BoxShadow(
                      color: PlayerTint.of(context).withValues(alpha: glowAlpha),
                      blurRadius: 8 + 4 * t,
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
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.bgMid,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: PlayerTint.of(context),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.bgMid,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: PlayerTint.of(context),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
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

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll;
  late final AnimationController _anim;
  double _maxScroll = 0;
  bool _reduceMotion = false;

  static const int _pauseMs = 1800;
  static const int _returnMs = 700;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _anim = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _restart();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion && _anim.isAnimating) _anim.stop();
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) {
      _anim.stop();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted || !_scroll.hasClients || _reduceMotion) return;
    _maxScroll = _scroll.position.maxScrollExtent;
    if (_maxScroll <= 0) return;
    _start();
  }

  void _start() {
    final scrollMs = (_maxScroll * 40).clamp(1200.0, 6000.0).toInt();
    _anim.duration =
        Duration(milliseconds: _pauseMs + scrollMs + _pauseMs + _returnMs);
    _anim.forward(from: 0);
  }

  void _restart() {
    if (!mounted || _reduceMotion) return;
    _measure();
  }

  void _onTick() {
    if (!_scroll.hasClients || _maxScroll <= 0) return;

    final scrollMs = (_maxScroll * 40).clamp(1200.0, 6000.0);
    final totalMs = _pauseMs + scrollMs + _pauseMs + _returnMs;
    final elapsed = _anim.value * totalMs;

    double pos;
    if (elapsed < _pauseMs) {
      pos = 0;
    } else if (elapsed < _pauseMs + scrollMs) {
      pos = _maxScroll * ((elapsed - _pauseMs) / scrollMs);
    } else if (elapsed < _pauseMs + scrollMs + _pauseMs) {
      pos = _maxScroll;
    } else {
      final t =
          ((elapsed - _pauseMs - scrollMs - _pauseMs) / _returnMs).clamp(0, 1);
      pos = _maxScroll * (1 - Curves.easeOutCubic.transform(t.toDouble()));
    }

    _scroll.jumpTo(pos.clamp(0, _maxScroll));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
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

/// While the row is dragged sideways: the song it goes to, as an icon on
/// the side it comes from, brighter as the swipe nears its threshold.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.dx, required this.threshold});

  final double dx;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final reach = (dx.abs() / threshold).clamp(0.0, 1.0);
    final next = dx < 0;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: next ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: reach,
            child: Transform.scale(
              scale: 0.7 + 0.3 * reach,
              child: Icon(
                next ? Icons.skip_next_rounded : Icons.skip_previous_rounded,
                size: 26,
                color: reach >= 1 ? PlayerTint.of(context) : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
