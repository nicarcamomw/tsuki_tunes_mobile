import 'track.dart';

/// Metadata kept with each play so history never depends on other lookups.
class PlayDayTrack {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String albumTitle;
  final String albumId;
  final String coverUrl;
  final String previewUrl;
  final int durationSeconds;

  const PlayDayTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId = '',
    this.albumTitle = '',
    this.albumId = '',
    this.coverUrl = '',
    this.previewUrl = '',
    this.durationSeconds = 0,
  });

  factory PlayDayTrack.fromTrack(Track t) => PlayDayTrack(
        id: t.id,
        title: t.title,
        artistName: t.fullArtistName,
        artistId: t.artistId,
        albumTitle: t.albumTitle,
        albumId: t.albumId,
        coverUrl: t.coverUrl,
        previewUrl: t.previewUrl,
        durationSeconds: t.durationSeconds,
      );

  // Short keys: one day can hold hundreds of tracks in a single document.
  factory PlayDayTrack.fromMap(String id, Map<String, dynamic> m) =>
      PlayDayTrack(
        id: id,
        title: '${m['t'] ?? ''}',
        artistName: '${m['a'] ?? ''}',
        artistId: '${m['ar'] ?? ''}',
        albumTitle: '${m['al'] ?? ''}',
        albumId: '${m['ai'] ?? ''}',
        coverUrl: '${m['c'] ?? ''}',
        previewUrl: '${m['p'] ?? ''}',
        durationSeconds: m['d'] is num ? (m['d'] as num).toInt() : 0,
      );

  Map<String, dynamic> toMap() => {
        't': title,
        'a': artistName,
        'ar': artistId,
        'al': albumTitle,
        'ai': albumId,
        'c': coverUrl,
        'p': previewUrl,
        'd': durationSeconds,
      };

  Track toTrack() => Track(
        id: id,
        title: title,
        artistId: artistId,
        artistName: artistName,
        albumId: albumId,
        albumTitle: albumTitle,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        durationSeconds: durationSeconds > 0 ? durationSeconds : 30,
      );
}

/// One device-local calendar day of listening:
/// `users/{uid}/playDays/{yyyy-MM-dd}`.
class PlayDay {
  final String date;
  final Map<String, int> plays;
  final Map<String, PlayDayTrack> tracks;
  final Map<int, int> hours;
  final int seconds;

  const PlayDay({
    required this.date,
    required this.plays,
    required this.tracks,
    this.hours = const {},
    this.seconds = 0,
  });

  DateTime get day => DateTime.parse(date);
  int get totalPlays => plays.values.fold(0, (s, v) => s + v);

  static String keyFor(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  factory PlayDay.fromFirestore(Map<String, dynamic> data, {String? id}) {
    Map<String, dynamic> asMap(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : const {};

    final plays = <String, int>{
      for (final e in asMap(data['plays']).entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    };
    final tracks = <String, PlayDayTrack>{
      for (final e in asMap(data['tracks']).entries)
        if (e.value is Map)
          e.key: PlayDayTrack.fromMap(e.key, Map<String, dynamic>.from(e.value)),
    };
    final hours = <int, int>{
      for (final e in asMap(data['hours']).entries)
        if (int.tryParse(e.key) != null && e.value is num)
          int.parse(e.key): (e.value as num).toInt(),
    };
    return PlayDay(
      date: '${data['date'] ?? id ?? ''}',
      plays: plays,
      tracks: tracks,
      hours: hours,
      seconds: data['seconds'] is num ? (data['seconds'] as num).toInt() : 0,
    );
  }
}
