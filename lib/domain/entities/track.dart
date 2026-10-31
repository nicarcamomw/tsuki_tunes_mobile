import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_readers.dart';

part 'track.freezed.dart';
part 'track.g.dart';

/// Someone credited on a track. Deezer and the stored JSON use the same
/// keys, so [Contributor.fromJson] reads both.
@freezed
abstract class Contributor with _$Contributor {
  const factory Contributor({
    @JsonKey(fromJson: jsonString) required String id,
    @JsonKey(defaultValue: '') required String name,
    String? role,
  }) = _Contributor;

  factory Contributor.fromJson(Map<String, dynamic> json) =>
      _$ContributorFromJson(json);
}

@freezed
abstract class Track with _$Track {
  const Track._();

  const factory Track({
    @JsonKey(fromJson: jsonString) required String id,
    @JsonKey(defaultValue: 'Unknown Track') required String title,
    @JsonKey(fromJson: jsonString) required String artistId,
    @JsonKey(defaultValue: 'Unknown Artist') required String artistName,
    @JsonKey(fromJson: jsonString) required String albumId,
    @JsonKey(defaultValue: '') required String albumTitle,
    @JsonKey(defaultValue: '') required String coverUrl,
    @JsonKey(defaultValue: '') required String previewUrl,
    @JsonKey(defaultValue: 30) required int durationSeconds,
    int? rank,
    @JsonKey(fromJson: jsonIsTrue) @Default(false) bool isExplicit,
    @Default([]) List<Contributor> contributors,
    String? link,
    // International Standard Recording Code. Deezer only returns it from
    // /track/{id}, not from search or album listings.
    @JsonKey(fromJson: jsonStringOrNull) String? isrc,
  }) = _Track;

  /// Reads the stored JSON written by [toJson].
  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  /// Reads a track from the Deezer API.
  factory Track.fromDeezer(Map<String, dynamic> json) {
    final artistJson =
        json['artist'] is Map<String, dynamic> ? json['artist'] : null;
    final albumJson =
        json['album'] is Map<String, dynamic> ? json['album'] : null;

    final String cover = albumJson?['cover_medium'] ??
        albumJson?['cover_big'] ??
        albumJson?['cover'] ??
        json['album_cover'] ??
        json['cover_medium'] ??
        '';

    List<Contributor> contribs = [];
    if (json['contributors'] is List) {
      contribs = (json['contributors'] as List)
          .map((c) => Contributor.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    String resolvedArtistName =
        artistJson?['name'] ?? json['artist_name'] ?? 'Unknown Artist';
    if (contribs.length > 1) {
      resolvedArtistName = contribs.map((c) => c.name).join(', ');
    }

    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['title_short'] ?? 'Unknown Track',
      artistId:
          artistJson?['id']?.toString() ?? json['artist_id']?.toString() ?? '',
      artistName: resolvedArtistName,
      albumId:
          albumJson?['id']?.toString() ?? json['album_id']?.toString() ?? '',
      albumTitle: albumJson?['title'] ?? json['album_title'] ?? '',
      coverUrl: cover,
      previewUrl: json['preview'] ?? '',
      durationSeconds: json['duration'] is int ? json['duration'] : 30,
      rank: json['rank'] is int ? json['rank'] : null,
      isExplicit: json['explicit_lyrics'] == true,
      contributors: contribs,
      link: json['link'],
      isrc: json['isrc']?.toString().isNotEmpty == true
          ? json['isrc'].toString()
          : null,
    );
  }

  String get fullArtistName {
    if (contributors.length > 1) {
      return contributors.map((c) => c.name).join(', ');
    }
    return artistName;
  }
}
