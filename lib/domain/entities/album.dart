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
    final artistJson =
        json['artist'] is Map<String, dynamic> ? json['artist'] : null;

    List<Track> parsedTracks = [];
    if (json['tracks'] != null && json['tracks']['data'] is List) {
      final List list = json['tracks']['data'];
      parsedTracks = list.map((t) {
        final trackMap = Map<String, dynamic>.from(t as Map);
        trackMap['album_cover'] = json['cover_medium'] ?? json['cover_big'];
        trackMap['album_title'] = json['title'];
        trackMap['artist_name'] =
            trackMap['artist']?['name'] ?? artistJson?['name'];
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
