import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_readers.dart';
import 'track.dart';

part 'album.freezed.dart';
part 'album.g.dart';

@freezed
abstract class Album with _$Album {
  const Album._();

  const factory Album({
    @JsonKey(fromJson: jsonString) required String id,
    @JsonKey(defaultValue: 'Unknown Album') required String title,
    @JsonKey(defaultValue: '') required String coverUrl,
    String? coverXl,
    @JsonKey(fromJson: jsonString) required String artistId,
    @JsonKey(defaultValue: 'Unknown Artist') required String artistName,
    @Default('') String releaseDate,
    @Default('album') String recordType,
    @Default(0) int fansCount,
    @Default(0) int tracksCount,
    String? link,
    /// Deezer's genre names for the album ("Rock", "Rap/Hip Hop"...).
    /// Left out of the stored JSON while empty.
    @JsonKey(includeIfNull: false, toJson: _genresToJson) @Default([]) List<String> genres,
    // Left out of the stored JSON while empty.
    @JsonKey(includeIfNull: false, toJson: _tracksToJson)
    @Default([])
    List<Track> tracks,
  }) = _Album;

  /// Reads the stored JSON written by [toJson].
  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);

  /// Reads an album from the Deezer API; its tracks get the album's cover,
  /// title and artist, which Deezer leaves out of them.
  factory Album.fromDeezer(Map<String, dynamic> json) {
    final artistJson = json['artist'] is Map<String, dynamic>
        ? json['artist'] as Map<String, dynamic>
        : null;

    List<Track> parsedTracks = [];
    final tracksJson = json['tracks'];
    if (tracksJson is Map && tracksJson['data'] is List) {
      final list = tracksJson['data'] as List;
      parsedTracks = list.map((t) {
        final trackMap = Map<String, dynamic>.from(t as Map);
        trackMap['album_cover'] = json['cover_medium'] ?? json['cover_big'];
        trackMap['album_title'] = json['title'];
        final trackArtist = trackMap['artist'];
        trackMap['artist_name'] =
            (trackArtist is Map ? trackArtist['name'] : null) ?? artistJson?['name'];
        trackMap['album_id'] = json['id']?.toString();
        return Track.fromDeezer(trackMap);
      }).toList();
    }

    return Album(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Album',
      coverUrl: json['cover_medium'] ?? json['cover_big'] ?? json['cover'] ?? '',
      coverXl: json['cover_xl'],
      artistId: artistJson?['id']?.toString() ?? '',
      artistName: artistJson?['name'] ?? 'Unknown Artist',
      releaseDate: json['release_date'] ?? '',
      recordType: json['record_type'] ?? 'album',
      fansCount: json['fans'] is int ? json['fans'] : 0,
      tracksCount:
          json['nb_tracks'] is int ? json['nb_tracks'] : parsedTracks.length,
      link: json['link'],
      genres: [
        if (json['genres'] case {'data': final List data})
          for (final g in data)
            if (g is Map && g['name'] is String) g['name'] as String,
      ],
      tracks: parsedTracks,
    );
  }

  String get year {
    if (releaseDate.length >= 4) return releaseDate.substring(0, 4);
    return '';
  }

  int get totalDurationSeconds {
    if (tracks.isEmpty) return 0;
    return tracks.fold(0, (sum, t) => sum + t.durationSeconds);
  }
}

List<Map<String, dynamic>>? _tracksToJson(List<Track> tracks) =>
    tracks.isEmpty ? null : [for (final t in tracks) t.toJson()];

List<String>? _genresToJson(List<String> genres) => genres.isEmpty ? null : genres;
