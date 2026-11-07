import '../entities/external_library.dart';
import '../entities/track.dart';
import 'search_suggestions.dart';

/// Finds a song of another service in Tsuki's catalog: by its ISRC first
/// (the same recording), then by searching its title and artist and taking
/// a result whose title and artist really match (and whose length is close,
/// when both are known), so a cover or a remix isn't taken for it.
class TrackMatcher {
  const TrackMatcher({required this.byIsrc, required this.search});

  final Future<Track?> Function(String isrc) byIsrc;
  final Future<List<Track>> Function(String query) search;

  static String _clean(String s) => SearchSuggestions.fold(
      s.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').replaceAll(RegExp(r'\s+-\s+.*$'), ''));

  Future<Track?> match(ExternalTrack t) async {
    final isrc = t.isrc?.trim();
    if (isrc != null && isrc.isNotEmpty) {
      try {
        final found = await byIsrc(isrc);
        if (found != null && found.id.isNotEmpty) return found;
      } catch (_) {}
    }
    if (t.title.trim().isEmpty || t.artists.isEmpty) return null;
    final title = _clean(t.title);
    final artist = _clean(t.artists.first);
    List<Track> results;
    try {
      results = await search('${t.artists.first} ${t.title}');
    } catch (_) {
      return null;
    }
    for (final r in results) {
      if (_clean(r.title) != title) continue;
      final ra = _clean(r.artistName);
      if (!(ra.contains(artist) || artist.contains(ra))) continue;
      if (t.durationMs > 0 && r.durationSeconds > 0 && (r.durationSeconds - t.durationMs / 1000).abs() > 15) continue;
      return r;
    }
    return null;
  }
}
