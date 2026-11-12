import '../logic/artist_names.dart';
import 'track.dart';

/// A song the user marked as listened, as the library keeps it: enough to
/// show it and to count albums and artists without asking the catalog.
class ListenedTrackData {
  final String trackId;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumId;
  final String coverUrl;
  final String previewUrl;
  final int duration;
  final DateTime? listenedAt;

  /// Each artist of the song (a collaboration has several). Songs marked
  /// before this was kept only have [artistName], all of them joined by
  /// commas: [hasArtistList] is false and this is a best guess.
  final List<String> artists;
  final bool hasArtistList;

  ListenedTrackData({
    required this.trackId,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumId,
    required this.coverUrl,
    this.previewUrl = '',
    required this.duration,
    this.listenedAt,
    List<String>? artists,
  })  : hasArtistList = artists != null && artists.isNotEmpty,
        artists = (artists != null && artists.isNotEmpty) ? artists : guessArtists(artistName);

  /// The artists in a joined name, until the real list is known. Anything
  /// [ArtistNames.split] misses is repaired from the catalog (see
  /// ListenedTracksRepository).
  static List<String> guessArtists(String joined) => ArtistNames.split(joined);

  static List<String>? _artistsFrom(Object? raw) =>
      raw is List ? [for (final a in raw) if (a != null && a.toString().trim().isNotEmpty) a.toString().trim()] : null;

  factory ListenedTrackData.fromTrack(Track track) => ListenedTrackData(
        trackId: track.id,
        title: track.title,
        artistName: track.fullArtistName,
        albumTitle: track.albumTitle,
        albumId: track.albumId,
        coverUrl: track.coverUrl,
        duration: track.durationSeconds,
        previewUrl: track.previewUrl,
        listenedAt: DateTime.now(),
        artists: track.contributors.length > 1
            ? [for (final c in track.contributors) if (c.name.isNotEmpty) c.name]
            : [if (track.artistName.isNotEmpty) track.artistName],
      );

  ListenedTrackData withArtists(List<String> artists) => ListenedTrackData(
        trackId: trackId,
        title: title,
        artistName: artistName,
        albumTitle: albumTitle,
        albumId: albumId,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        duration: duration,
        listenedAt: listenedAt,
        artists: artists,
      );

  /// Reads a song as the server stores it (see the data layer's
  /// Firestore mapping, which turns its timestamps into [DateTime] first).
  factory ListenedTrackData.fromStored(Map<String, dynamic> data,
      {String? docId}) {
    DateTime? listened;
    final rawListened = data['listenedAt'];
    if (rawListened is DateTime) {
      listened = rawListened;
    } else if (rawListened is Map) {
      final sec = rawListened['seconds'] ?? rawListened['_seconds'];
      if (sec is num) {
        listened = DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
      }
    } else if (rawListened is String) {
      listened = DateTime.tryParse(rawListened);
    }

    final tid = data['trackId']?.toString() ?? docId ?? '';
    final aid = data['albumId']?.toString() ?? '';
    final dur =
        data['duration'] is num ? (data['duration'] as num).toInt() : 0;

    return ListenedTrackData(
      trackId: tid,
      title: data['title']?.toString() ?? '',
      artistName: data['artistName']?.toString() ?? '',
      albumTitle: data['albumTitle']?.toString() ?? '',
      albumId: aid,
      coverUrl: data['coverUrl']?.toString() ?? '',
      previewUrl: data['previewUrl']?.toString() ?? '',
      duration: dur,
      listenedAt: listened,
      artists: _artistsFrom(data['artists']),
    );
  }

  /// Reads a song as this phone saves it ([toJson]). The same reading as
  /// [fromStored], so the two can't drift apart: it takes the date as text,
  /// as a [DateTime] or as a Firestore timestamp alike.
  factory ListenedTrackData.fromJson(Map<String, dynamic> json) =>
      ListenedTrackData.fromStored(json);

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
        'listenedAt': listenedAt?.toIso8601String(),
        if (hasArtistList) 'artists': artists,
      };

}
