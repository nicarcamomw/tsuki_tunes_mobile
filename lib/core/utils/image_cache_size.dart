import 'package:flutter/widgets.dart';

/// Decode width for a network image shown [logicalSize] wide.
///
/// Covers come from Deezer at up to 1000 px; decoding them at full size for a
/// 46 px thumbnail costs scroll smoothness and memory. Sizes are rounded up to
/// a few buckets so the same image is reused across screens.
int imageCacheSize(BuildContext context, double logicalSize) {
  final px = logicalSize * MediaQuery.devicePixelRatioOf(context);
  const buckets = [96, 160, 256, 384, 512, 768, 1080];
  for (final b in buckets) {
    if (px <= b) return b;
  }
  return buckets.last;
}
