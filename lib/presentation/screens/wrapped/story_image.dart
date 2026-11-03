import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../core/constants/app_colors.dart';

/// The size stories expect (Instagram, WhatsApp, TikTok): 9:16.
const storySize = Size(1080, 1920);

/// Lays a captured Wrapped slide out as a 1080×1920 story image.
///
/// Phones aren't 9:16 (most are taller), and the recap card is wider, so
/// the slide is never cropped: it goes whole in the middle, as large as it
/// fits above the [footer], over a blurred, darkened copy of itself that
/// fills the rest.
Future<ui.Image> composeStory(ui.Image slide, {String footer = 'TSUKI TUNES'}) async {
  const w = 1080.0, h = 1920.0;
  const top = 80.0, bottom = 180.0, side = 60.0;
  const full = Rect.fromLTWH(0, 0, w, h);
  final src = Rect.fromLTWH(0, 0, slide.width.toDouble(), slide.height.toDouble());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, full);

  // Background: the slide covering everything, blurred and darkened.
  canvas.drawRect(full, Paint()..color = const Color(0xFF07080C));
  final cover = Alignment.center.inscribe(applyBoxFit(BoxFit.cover, src.size, full.size).destination, full);
  canvas.saveLayer(
    full,
    Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50, tileMode: TileMode.mirror),
  );
  canvas.drawImageRect(slide, src, cover, Paint()..filterQuality = FilterQuality.low);
  canvas.restore();
  canvas.drawRect(full, Paint()..color = const Color(0xA6000000));

  // The slide, whole.
  final area = const Rect.fromLTRB(side, top, w - side, h - bottom);
  final fitted = applyBoxFit(BoxFit.contain, src.size, area.size).destination;
  final dst = Alignment.center.inscribe(fitted, area);
  final frame = RRect.fromRectAndRadius(dst, const Radius.circular(32));
  canvas.drawRRect(
    frame,
    Paint()
      ..color = AppColors.accent.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
  );
  canvas.save();
  canvas.clipRRect(frame);
  canvas.drawImageRect(slide, src, dst, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.accent.withValues(alpha: 0.7),
  );

  // Who made it.
  final mark = TextPainter(
    text: TextSpan(
      text: footer,
      style: const TextStyle(
        color: Color(0xE6FFFFFF),
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: 6,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: w - 2 * side);
  mark.paint(canvas, Offset((w - mark.width) / 2, h - bottom / 2 - mark.height / 2));
  mark.dispose();

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  picture.dispose();
  return image;
}
