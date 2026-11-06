import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/image_cache_size.dart';
import '../../domain/entities/oni_mask.dart';
import 'oni_mask_colors.dart';

/// Renders a collectible mask: dyed art inside a rarity frame, or its
/// locked silhouette (blurred and anonymous for secret masks).
class OniMaskArt extends StatelessWidget {
  final OniMask mask;
  final double size;
  final bool unlocked;
  final bool frame;

  const OniMaskArt({
    super.key,
    required this.mask,
    required this.size,
    required this.unlocked,
    this.frame = true,
  });

  static const List<double> _silhouette = [
    0, 0, 0, 0, 52,
    0, 0, 0, 0, 56,
    0, 0, 0, 0, 70,
    0, 0, 0, 0.9, 0,
  ];

  /// Just the illustration, dyed. Used anywhere a bare mask is needed.
  static Widget image(OniMask mask, double size,
      {List<double>? overrideFilter, int? cacheWidth}) {
    Widget img = Image.asset(
      mask.asset(),
      width: size,
      height: size,
      cacheWidth: cacheWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final filter = overrideFilter ?? mask.dye;
    if (filter != null) {
      img = ColorFiltered(colorFilter: ColorFilter.matrix(filter), child: img);
    }
    return img;
  }

  @override
  Widget build(BuildContext context) {
    final artSize = frame ? size * 0.78 : size;
    Widget art;
    if (unlocked) {
      art = image(mask, artSize, cacheWidth: imageCacheSize(context, artSize));
    } else {
      art = image(mask, artSize,
          overrideFilter: _silhouette, cacheWidth: imageCacheSize(context, artSize));
      if (mask.secret) {
        art = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: size * 0.05, sigmaY: size * 0.05),
          child: art,
        );
      }
    }

    if (!frame) return SizedBox.square(dimension: size, child: Center(child: art));

    final color = unlocked ? mask.rarityColor : AppColors.border;
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.75,
          // Opaque, or the outer glow would show through and flood the tile.
          colors: unlocked
              ? [
                  Color.alphaBlend(color.withValues(alpha: 0.20), AppColors.bgDeep),
                  Color.alphaBlend(color.withValues(alpha: 0.06), AppColors.bgDeep),
                  AppColors.bgDeep,
                ]
              : [AppColors.bgMid, AppColors.bgDeep, AppColors.bgDeep],
          stops: const [0.0, 0.6, 1.0],
        ),
        border: Border.all(
          color: unlocked ? color.withValues(alpha: 0.75) : AppColors.border,
          width: max(1, size * 0.015),
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: size * 0.15)]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          art,
          if (!unlocked && mask.secret)
            Text(
              '?',
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          if (!unlocked && !mask.secret)
            Positioned(
              right: size * 0.07,
              bottom: size * 0.07,
              child: Icon(Icons.lock_rounded, size: size * 0.16, color: AppColors.textMuted),
            ),
          // Their own kind: a divine Face, or the Chosen.
          if (unlocked && size >= 56 && (mask.divine || mask.chosen))
            Positioned(
              right: size * 0.07,
              top: size * 0.06,
              child: Icon(
                mask.chosen ? Icons.flare_rounded : Icons.auto_awesome_rounded,
                size: size * 0.13,
                color: color,
                shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8)],
              ),
            ),
          if (unlocked && size >= 56)
            Positioned(
              left: size * 0.08,
              top: size * 0.05,
              child: Text(
                mask.kanji,
                style: TextStyle(
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.85),
                  shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            ),
        ],
      ),
    );

    if (unlocked && mask.rarity == MaskRarity.ul) {
      return _LegendaryShimmer(
        size: size,
        // Divine Faces shine white and gold; the Chosen, crimson.
        colors: mask.chosen
            ? const [Color(0xFFFF8A9A), Color(0xFFFF1E3C)]
            : mask.divine
                ? const [Color(0xFFFFFFFF), Color(0xFFFFE9A8)]
                : const [Color(0xFFFFE9A8), Color(0xFFFFC94A)],
        twin: mask.divine || mask.chosen,
        child: box,
      );
    }
    return box;
  }
}

/// A slow light sweeping around the frame of the UL masks: golden, or in
/// their own [colors]. [twin]: two lights and a halo, for the divine Faces
/// and the Chosen.
class _LegendaryShimmer extends StatefulWidget {
  final double size;
  final Widget child;
  final List<Color> colors;
  final bool twin;

  const _LegendaryShimmer({required this.size, required this.child, required this.colors, this.twin = false});

  @override
  State<_LegendaryShimmer> createState() => _LegendaryShimmerState();
}

class _LegendaryShimmerState extends State<_LegendaryShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => CustomPaint(
        foregroundPainter: _ShimmerPainter(_c.value, widget.size, widget.colors, widget.twin),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  final double s;
  final List<Color> colors;
  final bool twin;

  _ShimmerPainter(this.t, this.s, this.colors, this.twin);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(s * 0.2));
    final light = colors.first, deep = colors.last;
    final clear = deep.withValues(alpha: 0);
    if (twin) {
      // A halo that breathes around the frame.
      final glow = 0.25 + 0.2 * sin(t * 2 * pi);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, s * 0.04)
          ..color = deep.withValues(alpha: glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, s * 0.05)),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, s * 0.025)
        ..shader = SweepGradient(
          transform: GradientRotation(t * 2 * pi),
          colors: twin
              ? [clear, light, deep, clear, clear, light, deep, clear, clear]
              : [clear, light, deep, clear, clear],
          stops: twin
              ? const [0.0, 0.08, 0.16, 0.3, 0.5, 0.58, 0.66, 0.8, 1.0]
              : const [0.0, 0.08, 0.16, 0.3, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t || old.colors != colors;
}
