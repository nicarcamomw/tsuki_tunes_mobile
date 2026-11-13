// A command-line tool: it reports with print.
// ignore_for_file: avoid_print

import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

// Monochrome layer for Android 13+ themed icons, from the adaptive icon's
// foreground (a render on the flat launcher background #181B22).
// The silhouette is solid; only large dark areas (eyes, mouth, vents) are
// cut out, so the face reads once Android tints it.
// Run from tool/monochrome_icon (dart pub get first):
//   dart run bin/generate.dart ../../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png mono.png preview.png 14 4 12 24
//   dart run bin/sizes.dart mono.png ../../android/app/src/main/res
// args: <foreground.png> <out.png> [preview.png or -] [darkLuma] [radius] [protect] [tolerance]
const bg = (24, 27, 34);

void main(List<String> a) {
  final src = img.decodePng(File(a[0]).readAsBytesSync())!;
  final w = src.width, h = src.height;
  final scale = w / 432; // thresholds tuned at xxxhdpi
  final darkLuma = a.length > 3 ? double.parse(a[3]) : 26.0;
  final r = max(1, ((a.length > 4 ? int.parse(a[4]) : 3) * scale).round());
  final protect = a.length > 5 ? int.parse(a[5]) : 12;
  double dist(img.Pixel p) =>
      sqrt(pow(p.r - bg.$1, 2) + pow(p.g - bg.$2, 2) + pow(p.b - bg.$3, 2)).toDouble();
  double luma(img.Pixel p) => 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;

  // 1. Background: flood fill from the border through near-background pixels.
  final tol = a.length > 6 ? double.parse(a[6]) : 8.0;
  final bgMask = List.filled(w * h, false);
  final q = Queue<int>();
  void seed(int x, int y) {
    final i = y * w + x;
    final p = src.getPixel(x, y);
    // The background and its soft shadow are bluish; the horns' dark side
    // is neutral or warm, so it stays part of the mask.
    if (!bgMask[i] && dist(p) <= tol && p.b - p.r >= 5) { bgMask[i] = true; q.add(i); }
  }
  for (var x = 0; x < w; x++) { seed(x, 0); seed(x, h - 1); }
  for (var y = 0; y < h; y++) { seed(0, y); seed(w - 1, y); }
  while (q.isNotEmpty) {
    final i = q.removeFirst();
    final x = i % w, y = i ~/ w;
    if (x > 0) seed(x - 1, y);
    if (x < w - 1) seed(x + 1, y);
    if (y > 0) seed(x, y - 1);
    if (y < h - 1) seed(x, y + 1);
  }

  // 2. Dark areas inside the mask, kept only where they're large and solid.
  List<bool> morph(List<bool> m, int rad, bool dilate) {
    final out = List.filled(w * h, false);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var hit = !dilate;
        for (var dy = -rad; dy <= rad && hit != dilate; dy++) {
          for (var dx = -rad; dx <= rad; dx++) {
            if (dx * dx + dy * dy > rad * rad) continue;
            final xx = x + dx, yy = y + dy;
            final v = xx >= 0 && yy >= 0 && xx < w && yy < h && m[yy * w + xx];
            if (dilate && v) { hit = true; break; }
            if (!dilate && !v) { hit = false; break; }
          }
        }
        out[y * w + x] = hit;
      }
    }
    return out;
  }
  var dark = List.generate(w * h, (i) => !bgMask[i] && luma(src.getPixel(i % w, i ~/ w)) < darkLuma);
  dark = morph(morph(dark, r, false), r, true); // opening: drop specks and shading
  dark = morph(morph(dark, 1, true), 1, false); // closing: clean holes
  // Only the large cut-outs stay (the eyes); small ones read as specks.
  {
    final seen = List.filled(w * h, false);
    final minArea = (220 * scale * scale).round();
    for (var i = 0; i < w * h; i++) {
      if (!dark[i] || seen[i]) continue;
      final blob = <int>[i];
      seen[i] = true;
      for (var k = 0; k < blob.length; k++) {
        final j = blob[k], x = j % w, y = j ~/ w;
        for (final n in [if (x > 0) j - 1, if (x < w - 1) j + 1, if (y > 0) j - w, if (y < h - 1) j + w]) {
          if (dark[n] && !seen[n]) { seen[n] = true; blob.add(n); }
        }
      }
      if (blob.length < minArea) {
        for (final j in blob) {
          dark[j] = false;
        }
      }
    }
  }
  // Small notches in the outline close up.
  {
    final solid = List.generate(w * h, (i) => !bgMask[i]);
    final closed = morph(morph(solid, max(1, (3 * scale).round()), true), max(1, (3 * scale).round()), false);
    for (var i = 0; i < w * h; i++) {
      if (closed[i]) bgMask[i] = false;
    }
  }
  // Cut-outs can't touch the outline (keeps the silhouette closed).
  final nearBg = morph(bgMask, max(1, (protect * scale).round()), true);

  // 3. Alpha, then a light blur for anti-aliasing.
  final alpha = List.generate(w * h, (i) => bgMask[i] ? 0.0 : (dark[i] && !nearBg[i] ? 0.0 : 1.0));
  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var s = 0.0, n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          s += alpha[yy * w + xx] * (dx == 0 && dy == 0 ? 4 : (dx == 0 || dy == 0 ? 2 : 1));
          n += dx == 0 && dy == 0 ? 4 : (dx == 0 || dy == 0 ? 2 : 1);
        }
      }
      out.setPixelRgba(x, y, 255, 255, 255, (s / n * 255).round());
    }
  }
  File(a[1]).writeAsBytesSync(img.encodePng(out));

  if (a.length > 2 && a[2] != '-') {
    // Preview: tinted like a themed icon on a light and a dark circle, 2x.
    final s = 432 * 2;
    final big = img.copyResize(out, width: s, height: s, interpolation: img.Interpolation.cubic);
    final pv = img.Image(width: s * 2 + 40, height: s + 20, numChannels: 4);
    img.fill(pv, color: img.ColorRgba8(250, 250, 250, 255));
    for (final (ox, back, tint) in [(10, (218, 226, 255), (30, 50, 110)), (s + 30, (40, 44, 56), (200, 214, 255))]) {
      for (var y = 0; y < s; y++) {
        for (var x = 0; x < s; x++) {
          final dx = x - s / 2, dy = y - s / 2;
          if (dx * dx + dy * dy > (s / 2) * (s / 2)) continue;
          final al = big.getPixel(x, y).a / 255;
          pv.setPixelRgba(ox + x, 10 + y, (back.$1 * (1 - al) + tint.$1 * al).round(),
              (back.$2 * (1 - al) + tint.$2 * al).round(), (back.$3 * (1 - al) + tint.$3 * al).round(), 255);
        }
      }
    }
    File(a[2]).writeAsBytesSync(img.encodePng(pv));
  }
}
