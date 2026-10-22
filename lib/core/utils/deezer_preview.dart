/// Deezer preview URLs are signed (`hdnea=exp=<unix seconds>~acl=…~hmac=…`)
/// and stop working once `exp` passes, so any previewUrl stored in playlists,
/// listened tracks or the persisted queue goes stale after a few hours.
class DeezerPreview {
  static final RegExp _expPattern = RegExp(r'exp=(\d+)');

  static bool isDeezerUrl(String url) =>
      url.contains('dzcdn.net') || url.contains('hdnea=');

  /// True when [url] is a signed Deezer preview that expires within [margin].
  static bool isExpired(String url,
      {Duration margin = const Duration(minutes: 2)}) {
    final match = _expPattern.firstMatch(url);
    if (match == null) return false;
    final exp = int.tryParse(match.group(1)!);
    if (exp == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().add(margin).isAfter(expiry);
  }
}
