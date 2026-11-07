import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import 'rinnegan_visualizer.dart';

/// The cover that flies between the mini player (a 44 px rounded square)
/// and the expanded player (the spinning disc).
///
/// Without its own flight the expanded player's disc would fly as it is:
/// drawn at full size from the first frame, on top of the mini player. The
/// flight instead morphs one into the other ([PlayerArtFlight]).
class PlayerArtHero extends StatelessWidget {
  final String trackId;
  final String coverUrl;
  final bool isPlaying;
  final Widget child;

  const PlayerArtHero({
    super.key,
    required this.trackId,
    required this.coverUrl,
    required this.isPlaying,
    required this.child,
  });

  static String tagFor(String trackId) => 'player_art_$trackId';

  @override
  Widget build(BuildContext context) => Hero(
        tag: tagFor(trackId),
        flightShuttleBuilder: _flight,
        child: child,
      );

  Widget _flight(BuildContext flightContext, Animation<double> animation, HeroFlightDirection direction,
      BuildContext fromHeroContext, BuildContext toHeroContext) {
    // Closing: the disc leaves at whatever angle it was spinning and unwinds
    // on the way down, instead of snapping upright.
    final spin = direction == HeroFlightDirection.pop ? RinneganVisualizer.rotationIn(fromHeroContext) : 0.0;
    // The disc is the bigger end; its cover is decoded at that size.
    final disc = [fromHeroContext, toHeroContext]
        .map((c) => c.findRenderObject())
        .map((box) => box is RenderBox && box.hasSize ? box.size.shortestSide : 0.0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return PlayerArtFlight(
      animation: animation,
      coverUrl: coverUrl,
      isPlaying: isPlaying,
      rotation: spin,
      coverCacheWidth: imageCacheSize(flightContext, disc * RinneganVisualizer.coverFraction),
    );
  }
}

/// What flies: at 0 the mini player's square cover, at 1 the expanded
/// player's disc (a dark circle holding the round cover). The route's
/// [animation] runs 0 to 1 on opening and back on closing.
class PlayerArtFlight extends StatelessWidget {
  final Animation<double> animation;
  final String coverUrl;
  final bool isPlaying;
  final double rotation;

  /// The decode width of the disc's cover, shared with the expanded player
  /// so the image is decoded once.
  final int? coverCacheWidth;

  /// The mini player's cover corner, at 44 px.
  static const double miniRadius = 3.5;

  const PlayerArtFlight({
    super.key,
    required this.animation,
    required this.coverUrl,
    this.isPlaying = false,
    this.rotation = 0,
    this.coverCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Decoded at the disc's size, with the mini player's (already in memory)
    // underneath until it is, so the flight never starts blank.
    final small = imageCacheSize(context, 44);
    final image = coverUrl.isEmpty
        ? const ColoredBox(color: AppColors.bgMid)
        : CachedNetworkImage(
            imageUrl: coverUrl,
            memCacheWidth: coverCacheWidth,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => CachedNetworkImage(
              imageUrl: coverUrl,
              memCacheWidth: small,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => const ColoredBox(color: AppColors.bgMid),
              errorWidget: (_, _, _) => const ColoredBox(color: AppColors.bgMid),
            ),
            errorWidget: (_, _, _) => const ColoredBox(color: AppColors.bgMid),
          );

    return AnimatedBuilder(
      animation: animation,
      child: image,
      builder: (context, image) => LayoutBuilder(builder: (context, box) {
        final t = Curves.fastOutSlowIn.transform(animation.value.clamp(0.0, 1.0));
        final size = box.biggest.shortestSide;
        final cover = size * lerpDouble(1, RinneganVisualizer.coverFraction, t)!;
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: Transform.rotate(
              angle: rotation * t,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The disc appears around the cover as it grows.
                  Opacity(
                    opacity: t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgDeep,
                        border: Border.all(color: isPlaying ? AppColors.accent : AppColors.border, width: 2),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(lerpDouble(miniRadius, cover / 2, t)!),
                    child: SizedBox.square(dimension: cover, child: image),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
