import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/expanded_player_screen.dart';
import '../screens/main_navigation_screen.dart';
import 'oni_mask_icon.dart';
import 'tap_scale.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _swipeDx = 0;
  bool _swipeLocked = false;
  bool _hapticFired = false;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetAnimation = const AlwaysStoppedAnimation(0.0);
    _resetController.addListener(() {
      setState(() => _swipeDx = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_swipeLocked) return;
    setState(() {
      _swipeDx = (_swipeDx + details.delta.dx).clamp(-160.0, 160.0);
      if (!_hapticFired && _swipeDx.abs() > _swipeThreshold) {
        _hapticFired = true;
        HapticFeedback.lightImpact();
      } else if (_hapticFired && _swipeDx.abs() < _swipeThreshold * 0.6) {
        _hapticFired = false;
      }
    });
  }

  double get _swipeThreshold {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.2).clamp(70.0, 120.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details, AudioProvider audio) {
    if (_swipeLocked) return;

    final velocity = details.primaryVelocity ?? 0;
    final hasQueue = audio.queue.length > 1;
    final fastSwipe = velocity.abs() > 700;
    final farSwipe = _swipeDx.abs() > _swipeThreshold;
    final triggered = hasQueue && !audio.isBuffering && (fastSwipe || farSwipe);

    if (triggered) {
      final goNext = fastSwipe ? velocity < 0 : _swipeDx < 0;
      _swipeLocked = true;
      HapticFeedback.mediumImpact();

      if (goNext) {
        audio.next();
      } else {
        audio.previous();
      }
    }

    _hapticFired = false;
    _resetAnimation = Tween<double>(begin: _swipeDx, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0).whenComplete(() {
      _swipeLocked = false;
    });
  }

  void _openExpandedPlayer(BuildContext context) {
    NavigationEvents.isPlayerExpanded.value = true;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, anim, secondaryAnim) =>
            const ExpandedPlayerScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
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
    ).whenComplete(() {
      NavigationEvents.isPlayerExpanded.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final track = audio.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final library = context.watch<LibraryProvider>();
    final locale = context.read<LocaleProvider>();
    final isListened = library.isTrackListened(track.id);

    final double progress = audio.duration.inMilliseconds > 0
        ? (audio.position.inMilliseconds / audio.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final swipeOpacity = (1 - (_swipeDx.abs() / 200)).clamp(0.3, 1.0);

    return Semantics(
      label: '${track.title}, ${track.fullArtistName}',
      child: RepaintBoundary(
      child: GestureDetector(
        onTap: () => _openExpandedPlayer(context),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) {
            _openExpandedPlayer(context);
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.8),
            child: Container(
              color: AppColors.bgCard,
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: (details) =>
                _onHorizontalDragEnd(details, audio),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Transform.translate(
                            offset: Offset(_swipeDx * 0.3, 0),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(
                                    alpha: (1.0 - swipeOpacity) * 0.7),
                                BlendMode.srcATop,
                              ),
                              child: Row(
                                children: [
                                  _BreathingCover(
                                    trackId: track.id,
                                    coverUrl: track.coverUrl,
                                    isPlaying: audio.isPlaying,
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
                                          text: audio.spotifyFallbackActive
                                              ? '${track.fullArtistName}  ·  Preview'
                                              : track.fullArtistName,
                                          style: locale.getTextStyle(
                                            fontSize: 11,
                                            color: audio.spotifyFallbackActive
                                                ? AppColors.accent.withValues(alpha: 0.7)
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
                      const SizedBox(width: 10),
                      // Oni mask (listened toggle)
                      Tooltip(
                        message: isListened
                            ? locale.strings.unmarkAsListened
                            : locale.strings.markAsListened,
                        child: TapScale(
                          semanticLabel: isListened
                              ? locale.strings.unmarkAsListened
                              : locale.strings.markAsListened,
                          onTap: () {
                            if (isListened) {
                              library.unmarkTrack(track.id);
                            } else {
                              library.markTrack(track);
                            }
                          },
                          scaleDown: 0.8,
                          child: OniMaskIcon(
                            isActive: isListened,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Play / Pause
                      TapScale(
                        semanticLabel: audio.isPlaying ? locale.strings.a11yPause : locale.strings.a11yPlay,
                        onTap: audio.isBuffering ? null : audio.togglePlay,
                        scaleDown: 0.85,
                        child: audio.isBuffering
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accent),
                                ),
                              )
                            : Icon(
                                audio.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 32,
                                color: AppColors.accent,
                              ),
                      ),
                      const SizedBox(width: 8),
                      // Close / Stop
                      TapScale(
                        semanticLabel: locale.strings.a11yStop,
                        onTap: () => audio.stop(),
                        scaleDown: 0.85,
                        child: const Icon(Icons.close,
                            size: 20, color: AppColors.textMuted),
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
    ),
    );
  }
}

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
  void didUpdateWidget(_BreathingCover old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating) {
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
              color: AppColors.accent.withValues(alpha: borderAlpha),
              width: 1.5,
            ),
            boxShadow: widget.isPlaying
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: glowAlpha),
                      blurRadius: 8 + 4 * t,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Hero(
        tag: 'player_art_${widget.trackId}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3.5),
          child: SizedBox(
            width: 44,
            height: 44,
            child: widget.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.bgMid),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.bgMid,
                      child: const Icon(Icons.music_note,
                          color: AppColors.accent),
                    ),
                  )
                : Container(
                    color: AppColors.bgMid,
                    child: const Icon(Icons.music_note,
                        color: AppColors.accent),
                  ),
          ),
        ),
      ),
    );
  }
}

/// _MarqueeText: Desplaza suavemente títulos o artistas largos en lugar de recortarlos
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
  }

  @override
  void didUpdateWidget(_MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
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
        // El texto cabe perfectamente; no requiere scroll
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      // Pausa inicial antes de comenzar a desplazarse
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      // Desplazamiento suave hacia el final (~24 px/segundo)
      final duration = Duration(
        milliseconds: (maxScroll * 40).clamp(1200, 6000).toInt(),
      );
      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );

      // Pausa para leer el final
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      // Retorno suave al inicio
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
