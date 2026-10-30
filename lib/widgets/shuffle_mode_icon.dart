import 'package:flutter/material.dart';

import '../models/smart_shuffle.dart';

/// The shuffle icon for each [ShuffleMode]. With recommendations (smart)
/// a sparkle sits at the top left of the arrows.
class ShuffleModeIcon extends StatelessWidget {
  final ShuffleMode mode;
  final double size;
  final Color color;

  const ShuffleModeIcon({
    super.key,
    required this.mode,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (mode != ShuffleMode.smart) {
      return Icon(Icons.shuffle, size: size, color: color);
    }
    return SizedBox(
      width: size * 1.2,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.shuffle, size: size * 0.8, color: color),
          ),
          Positioned(
            left: 0,
            top: -size * 0.04,
            child: SparkleIcon(size: size * 0.55, color: color),
          ),
        ],
      ),
    );
  }
}

/// A four-pointed sparkle, the mark of recommended songs.
class SparkleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final String? semanticLabel;

  const SparkleIcon({
    super.key,
    required this.color,
    this.size = 16,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color),
    );
    if (semanticLabel == null) return icon;
    return Semantics(label: semanticLabel, child: icon);
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  const _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    // Concave sides: each edge curves in towards the centre.
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + w * 0.07, cy - h * 0.07, w, cy)
      ..quadraticBezierTo(cx + w * 0.07, cy + h * 0.07, cx, h)
      ..quadraticBezierTo(cx - w * 0.07, cy + h * 0.07, 0, cy)
      ..quadraticBezierTo(cx - w * 0.07, cy - h * 0.07, cx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
