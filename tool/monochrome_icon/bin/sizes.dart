// A command-line tool: it reports with print.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:image/image.dart' as img;
// Writes the monochrome layer at every density from the xxxhdpi one.
void main(List<String> a) {
  final src = img.decodePng(File(a[0]).readAsBytesSync())!;
  const sizes = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};
  sizes.forEach((d, s) {
    final out = s == src.width ? src : img.copyResize(src, width: s, height: s, interpolation: img.Interpolation.average);
    final path = '${a[1]}/mipmap-$d/ic_launcher_monochrome.png';
    File(path).writeAsBytesSync(img.encodePng(out, level: 9));
    print('$path ${out.width}x${out.height}');
  });
}
