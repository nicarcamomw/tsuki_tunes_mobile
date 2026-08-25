import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../screens/expanded_player_screen.dart';

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
    )..addListener(() {
        setState(() => _swipeDx = _resetAnimation.value);
      });
    _resetController.forward(from: 0);
  }

  void _openExpandedPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim, secondaryAnim) =>
            const ExpandedPlayerScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutExpo,
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
    );
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
                                                      color: AppColors.bgMid),
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: AppColors.bgMid,
                                                child: const Icon(
                                                    Icons.music_note,
                                                    color: AppColors.accent),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textBright,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.fullArtistName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                    IconButton(
                      iconSize: 20,
                      icon: Icon(
                        isListened
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: isListened
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      onPressed: () {
                        if (isListened) {
                          library.unmarkTrack(track.id);
                        } else {
                          library.markTrack(track);
                        }
                      },
                    ),
                    IconButton(
                      iconSize: 28,
                      icon: audio.isBuffering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
                              color: AppColors.accent,
                            ),
                      onPressed: audio.togglePlay,
                    ),
                    IconButton(
                      iconSize: 22,
                      icon: const Icon(Icons.skip_next,
                          color: AppColors.textPrimary),
                      onPressed: audio.next,
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
