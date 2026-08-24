import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';

class RinneganVisualizer extends StatefulWidget {
  final bool isPlaying;
  final String? imageUrl;
  final double size;

  const RinneganVisualizer({
    super.key,
    required this.isPlaying,
    this.imageUrl,
    this.size = 220,
  });

  @override
  State<RinneganVisualizer> createState() => _RinneganVisualizerState();
}

class _RinneganVisualizerState extends State<RinneganVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RinneganVisualizer oldWidget) {
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2 * pi,
            child: child,
          );
        },
        child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgDeep,
          border: Border.all(
            color: widget.isPlaying ? AppColors.accent : AppColors.border,
            width: 2,
          ),
          boxShadow: widget.isPlaying
              ? [
                  const BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Concentric Rinnegan/Disc circles
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RinneganDiscPainter(isPlaying: widget.isPlaying),
            ),

            // Inner Album Cover / Artwork
            ClipOval(
              child: SizedBox(
                width: widget.size * 0.58,
                height: widget.size * 0.58,
                child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.bgMid,
                          child: const Icon(Icons.music_note, color: AppColors.accent),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.bgMid,
                          child: const Icon(Icons.music_note, color: AppColors.accent),
                        ),
                      )
                    : Container(
                        color: AppColors.bgMid,
                        child: const Icon(Icons.music_note, size: 40, color: AppColors.accent),
                      ),
              ),
            ),

            // Center Pin
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgDeep,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RinneganDiscPainter extends CustomPainter {
  final bool isPlaying;

  _RinneganDiscPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = isPlaying ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border
      ..strokeWidth = 1.0;

    // Draw concentric groove rings
    final radiusList = [
      size.width * 0.44,
      size.width * 0.38,
      size.width * 0.32,
    ];

    for (var r in radiusList) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RinneganDiscPainter oldDelegate) =>
      oldDelegate.isPlaying != isPlaying;
}
