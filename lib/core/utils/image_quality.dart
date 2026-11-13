/// How big the large images (the player's cover, an album's, an artist's
/// photo, discovery's cards) are fetched. Thumbnails in lists stay as they
/// are in every mode.
enum ImageQuality {
  /// Large images at 250 px: least data on mobile.
  dataSaver,

  /// As the app always did.
  normal,

  /// Large images at 1000 px, the most Deezer has.
  high;

  static ImageQuality fromName(String? name) =>
      values.firstWhere((q) => q.name == name, orElse: () => normal);

  /// [url] for a large image in this mode. Only Deezer's images can be
  /// asked at another size; any other URL is left alone.
  String large(String url) => switch (this) {
        normal => url,
        high => deezerImageAt(url, 1000),
        dataSaver => deezerImageAt(url, 250),
      };
}

final _deezerSize = RegExp(r'/(\d+)x(\d+)-');

/// A Deezer image (cover or artist photo) at [size] px: its URL carries the
/// size (`…/250x250-000000-80-0-0.jpg`), and Deezer serves any up to 1000.
String deezerImageAt(String url, int size) {
  if (!url.contains('dzcdn.net') || !_deezerSize.hasMatch(url)) return url;
  return url.replaceFirst(_deezerSize, '/${size}x$size-');
}
