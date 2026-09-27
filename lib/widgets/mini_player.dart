import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
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
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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
    setState(() {
      _swipeDx += details.delta.dx;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, AudioProvider audio) {
    final velocity = details.primaryVelocity ?? 0;
    if (_swipeDx.abs() > 60 || velocity.abs() > 400) {
      if (_swipeDx > 0 || velocity > 400) {
        audio.previous();
      } else {
        audio.next();
      }
    }
    final startValue = _swipeDx;
    _resetAnimation = Tween<double>(begin: startValue, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0);
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
    final isListened = library.isTrackListened(track.id);

    final double progress = audio.duration.inMilliseconds > 0
        ? (audio.position.inMilliseconds / audio.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final swipeOpacity = (1 - (_swipeDx.abs() / 200)).clamp(0.3, 1.0);

    return RepaintBoundary(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) {
            _openExpandedPlayer(context);
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 12,
                spreadRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openExpandedPlayer(context),
                        onHorizontalDragUpdate: _onHorizontalDragUpdate,
                        onHorizontalDragEnd: (details) =>
                            _onHorizontalDragEnd(details, audio),
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
                                // Carátula de 44x44 con Micro-ecualizador en esquina
                                Stack(
                                  children: [
                                    Hero(
                                      tag: 'player_art_${track.id}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: track.coverUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: track.coverUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                          color:
                                                              AppColors.bgMid),
                                                  errorWidget: (_, __, ___) =>
                                                      Container(
                                                    color: AppColors.bgMid,
                                                    child: const Icon(
                                                        Icons.music_note,
                                                        color:
                                                            AppColors.accent),
                                                  ),
                                                )
                                              : Container(
                                                  color: AppColors.bgMid,
                                                  child: const Icon(
                                                      Icons.music_note,
                                                      color: AppColors.accent),
                                                ),
                                        ),
                                      ),
                                    ),
                                    if (audio.isPlaying)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 2.5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.78),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                              color: AppColors.accent
                                                  .withValues(alpha: 0.4),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: _MiniEqualizer(
                                              isPlaying: audio.isPlaying),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Textos con desplazamiento automático Marquee
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MarqueeText(
                                        text: track.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textBright,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      _MarqueeText(
                                        text: track.fullArtistName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
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
                          size: 24,
                        ),
                      ),
                    ),
                    TapScale(
                      semanticLabel: audio.isPlaying ? 'Pause' : 'Play',
                      onTap: audio.togglePlay,
                      scaleDown: 0.85,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: audio.isBuffering
                            ? const SizedBox(
                                width: 28,
                                height: 28,
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
                                size: 28,
                                color: AppColors.accent,
                              ),
                      ),
                    ),
                    TapScale(
                      semanticLabel: 'Next track',
                      onTap: audio.next,
                      scaleDown: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.skip_next,
                            size: 22, color: AppColors.textPrimary),
                      ),
                    ),
                    TapScale(
                      semanticLabel: 'Stop playback',
                      onTap: audio.stop,
                      scaleDown: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            size: 18, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// _MiniEqualizer: 3 barritas danzantes en la esquina de la carátula
class _MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  const _MiniEqualizer({required this.isPlaying});

  @override
  State<_MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<_MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
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
      builder: (context, _) {
        final t = _controller.value * 2 * pi;
        return SizedBox(
          height: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(widget.isPlaying ? 2.5 + 6.5 * (sin(t * 1.8).abs()) : 3.0),
              const SizedBox(width: 1.5),
              _buildBar(widget.isPlaying ? 2.5 + 7.5 * (sin(t * 2.4 + 1.2).abs()) : 7.0),
              const SizedBox(width: 1.5),
              _buildBar(widget.isPlaying ? 2.5 + 5.5 * (sin(t * 1.4 + 2.4).abs()) : 4.0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.0,
      height: height.clamp(2.0, 10.0),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.accentGlow,
            blurRadius: 3,
          ),
        ],
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
