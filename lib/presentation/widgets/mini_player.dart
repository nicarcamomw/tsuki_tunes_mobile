import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import '../screens/expanded_player_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../state/app_providers.dart';
import '../state/audio_provider.dart';
import '../state/cover_colors.dart';
import '../state/use_cases.dart';
import 'audio_progress_selector.dart';
import 'haptics.dart';
import 'oni_mask_icon.dart';
import 'player_art_hero.dart';
import 'player_tint.dart';
import 'tap_scale.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _swipeDx = 0;
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

  void _openExpandedPlayer(BuildContext context) {
    NavigationEvents.isPlayerExpanded.value = true;
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 280),
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

    return Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () { Haptics.tap(); _openExpandedPlayer(context); },
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -300) {
              _openExpandedPlayer(context);
            }
          },
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, audio),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PlayerTint.of(context), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: PlayerTint.glowOf(context),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.8),
              child: AnimatedContainer(
                duration: AnimatedPlayerTint.duration,
                curve: Curves.easeOut,
                // The cover's colour seeps in from the artwork's side.
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [coverBackground ?? AppColors.bgCard, AppColors.bgCard],
                    stops: const [0.0, 0.7],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _MiniProgressBar(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // --- Track info (swipeable) ---
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(_swipeDx * 0.3, 0),
                              // Opacity at 1.0 adds no layer; the old color
                              // filter forced an offscreen pass every frame.
                              child: Opacity(
                                opacity: 1.0 - (1.0 - swipeOpacity) * 0.7,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
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
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textBright,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            _MarqueeText(
                                              text: spotifyFallbackActive
                                                  ? '${track.fullArtistName}  ·  Preview'
                                                  : track.fullArtistName,
                                              style: locale.getTextStyle(
                                                fontSize: 11,
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
                                    ref.read(toggleTrackListenedProvider)(track),
                                scaleDown: 0.8,
                                child: OniMaskIcon(
                                  isActive: isListened,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                          // --- Play / Pause ---
                          TapScale(
                            semanticLabel: isPlaying
                                ? locale.strings.a11yPause
                                : locale.strings.a11yPlay,
                            onTap: isBuffering ? null : audio.togglePlay,
                            scaleDown: 0.85,
                            child: isBuffering
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        PlayerTint.of(context),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 32,
                                    color: PlayerTint.of(context),
                                  ),
                          ),
                          // --- Close / Stop ---
                          TapScale(
                            semanticLabel: locale.strings.a11yStop,
                            onTap: () => audio.stop(),
                            scaleDown: 0.85,
                            child: const Icon(
                              Icons.close,
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
      duration: const Duration(milliseconds: 2000),
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
            borderRadius: BorderRadius.circular(5),
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
            borderRadius: BorderRadius.circular(3.5),
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
                          Icons.music_note,
                          color: PlayerTint.of(context),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.bgMid,
                      child: Icon(
                        Icons.music_note,
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

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context) {
    return AudioProgressSelector<double>(
      selector: (a) {
        final total = a.duration.inMilliseconds;
        if (total <= 0) return 0.0;
        return (a.position.inMilliseconds / total).clamp(0.0, 1.0);
      },
      builder: (context, progress) => LinearProgressIndicator(
        value: progress,
        minHeight: 2.5,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(PlayerTint.of(context)),
      ),
    );
  }
}
