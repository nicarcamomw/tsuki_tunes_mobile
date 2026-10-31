// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radar_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RadarRelease _$RadarReleaseFromJson(Map json) => _RadarRelease(
  albumId: jsonString(json['albumId']),
  title: json['title'] as String? ?? '',
  artistId: jsonString(json['artistId']),
  artistName: json['artistName'] as String? ?? '',
  coverUrl: json['coverUrl'] as String? ?? '',
  releaseDate: json['releaseDate'] as String? ?? '',
  recordType: json['recordType'] as String? ?? 'album',
  detectedAt: jsonDateOrEpoch(json['detectedAt']),
  isNew: jsonIsTrue(json['isNew']),
  read: jsonIsNotFalse(json['read']),
);

Map<String, dynamic> _$RadarReleaseToJson(_RadarRelease instance) =>
    <String, dynamic>{
      'albumId': instance.albumId,
      'title': instance.title,
      'artistId': instance.artistId,
      'artistName': instance.artistName,
      'coverUrl': instance.coverUrl,
      'releaseDate': instance.releaseDate,
      'recordType': instance.recordType,
      'detectedAt': instance.detectedAt.toIso8601String(),
      'isNew': instance.isNew,
      'read': instance.read,
    };
