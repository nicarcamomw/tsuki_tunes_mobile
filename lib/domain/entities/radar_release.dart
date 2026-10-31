import 'package:freezed_annotation/freezed_annotation.dart';

import 'album.dart';
import 'json_readers.dart';

part 'radar_release.freezed.dart';
part 'radar_release.g.dart';

/// A recent release by a watched artist, as tracked by the release radar.
@freezed
abstract class RadarRelease with _$RadarRelease {
  const RadarRelease._();

  const factory RadarRelease({
    @JsonKey(fromJson: jsonString) required String albumId,
    @JsonKey(defaultValue: '') required String title,
    @JsonKey(fromJson: jsonString) required String artistId,
    @JsonKey(defaultValue: '') required String artistName,
    @JsonKey(defaultValue: '') required String coverUrl,
    @JsonKey(defaultValue: '') required String releaseDate,
    @JsonKey(defaultValue: 'album') required String recordType,
    @JsonKey(fromJson: jsonDateOrEpoch) required DateTime detectedAt,

    /// True when it appeared after the artist's baseline (a genuinely new drop),
    /// false for releases that already existed when the radar started watching.
    @JsonKey(fromJson: jsonIsTrue) required bool isNew,
    @JsonKey(fromJson: jsonIsNotFalse) required bool read,
  }) = _RadarRelease;

  factory RadarRelease.fromJson(Map<String, dynamic> json) =>
      _$RadarReleaseFromJson(json);

  factory RadarRelease.fromAlbum(
    Album album, {
    required String artistId,
    required String artistName,
    required DateTime detectedAt,
    required bool isNew,
  }) {
    return RadarRelease(
      albumId: album.id,
      title: album.title,
      artistId: artistId,
      artistName: artistName,
      coverUrl: album.coverUrl,
      releaseDate: album.releaseDate,
      recordType: album.recordType,
      detectedAt: detectedAt,
      isNew: isNew,
      read: !isNew,
    );
  }

  bool get isUnread => isNew && !read;

  DateTime? get releasedAt => DateTime.tryParse(releaseDate);

  Album toAlbum() => Album(
        id: albumId,
        title: title,
        coverUrl: coverUrl,
        artistId: artistId,
        artistName: artistName,
        releaseDate: releaseDate,
        recordType: recordType,
      );
}
