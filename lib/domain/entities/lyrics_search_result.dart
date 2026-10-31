class LyricsSearchResult {
  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final String? plainLyrics;
  final String? syncedLyrics;
  final bool instrumental;

  const LyricsSearchResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    this.plainLyrics,
    this.syncedLyrics,
    this.instrumental = false,
  });

  factory LyricsSearchResult.fromJson(Map<String, dynamic> json) {
    return LyricsSearchResult(
      id: json['id'] is int ? json['id'] : 0,
      trackName: json['trackName'] ?? json['name'] ?? '',
      artistName: json['artistName'] ?? '',
      albumName: json['albumName'] ?? '',
      duration: json['duration'] is num ? (json['duration'] as num).toInt() : 0,
      plainLyrics: json['plainLyrics'],
      syncedLyrics: json['syncedLyrics'],
      instrumental: json['instrumental'] == true,
    );
  }

  String get lyricsSnippet {
    final text = plainLyrics ?? syncedLyrics ?? '';
    if (text.isEmpty) return '';
    final lines = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    final take = lines.length > 3 ? 3 : lines.length;
    return lines.sublist(0, take).join(' / ');
  }

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
