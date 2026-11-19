import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import 'tsuki_sky.dart';

/// Draws, once and off screen, a little of everything the app draws: the
/// gradients (linear, radial, sweep), blurs and blurred layers, clips with
/// anti-aliasing, layers blended into others, rounded rectangles, text and
/// the login's halo.
///
/// The first time the GPU meets each of those it builds what it needs to
/// draw it, a hitch the first frames of a fresh install paid for. Run on
/// the loading screen while a first start gets ready (SessionGate
/// preparing), the hitch lands there, behind a screen that's waiting
/// anyway.
abstract final class RenderWarmUp {
  static const double _size = 96;

  /// Draws the scene into a small image and drops it.
  static Future<void> run() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(_size.toInt(), _size.toInt());
      image.dispose();
      picture.dispose();
    } catch (_) {
      // Only a head start: drawing it later works the same.
    }
  }

  static void _paint(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, _size, _size);
    final c = rect.center;
    // Gradients.
    canvas
      ..drawRect(
        rect,
        Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(_size, _size), [AppColors.bgDeep, AppColors.accent]),
      )
      ..drawCircle(
        c,
        40,
        Paint()..shader = ui.Gradient.radial(c, 40, [AppColors.accent, AppColors.accent.withValues(alpha: 0)]),
      )
      ..drawArc(
        rect.deflate(10),
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.sweep(c, [Colors.transparent, AppColors.accent], const [0, 1], TileMode.clamp, 0, math.pi),
      );
    // A blurred layer (glass, glows) and a blur of what's below (backdrops).
    canvas
      ..saveLayer(rect, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8))
      ..drawRRect(RRect.fromRectAndRadius(rect.deflate(20), const Radius.circular(AppRadius.card)), Paint()..color = Colors.white24)
      ..restore()
      ..saveLayer(rect, Paint())
      ..drawCircle(c, 30, Paint()..color = AppColors.accent)
      ..drawRect(rect, Paint()..blendMode = BlendMode.dstIn..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _size), [Colors.black, Colors.transparent]))
      ..restore();
    // Clips (rounded, anti-aliased), shadows and a mask filter.
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(AppRadius.sheet)))
      ..drawShadow(Path()..addOval(Rect.fromCircle(center: c, radius: 20)), Colors.black, 6, true)
      ..drawCircle(c, 12, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4))
      ..restore();
    // Text.
    final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: AppFontSize.title, fontWeight: FontWeight.w800))
          ..pushStyle(ui.TextStyle(color: Colors.white))
          ..addText('TSUKI'))
        .build()
      ..layout(const ui.ParagraphConstraints(width: _size));
    canvas.drawParagraph(paragraph, const Offset(4, 4));
    // The login's halo, mid-burst.
    HaloRingPainter(
      rotation: ValueNotifier(1),
      assemble: const AlwaysStoppedAnimation(1),
      exit: const AlwaysStoppedAnimation(0.2),
      burst: const AlwaysStoppedAnimation(0.3),
      still: false,
      radius: 30,
    ).paint(canvas, rect.size);
  }
}
