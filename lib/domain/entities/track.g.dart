// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Contributor _$ContributorFromJson(Map json) => _Contributor(
  id: jsonString(json['id']),
  name: json['name'] as String? ?? '',
  role: json['role'] as String?,
);

Map<String, dynamic> _$ContributorToJson(_Contributor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
    };

_Track _$TrackFromJson(Map json) => _Track(
  id: jsonString(json['id']),
  title: json['title'] as String? ?? 'Unknown Track',
  artistId: jsonString(json['artistId']),
  artistName: json['artistName'] as String? ?? 'Unknown Artist',
  albumId: jsonString(json['albumId']),
  albumTitle: json['albumTitle'] as String? ?? '',
  coverUrl: json['coverUrl'] as String? ?? '',
  previewUrl: json['previewUrl'] as String? ?? '',
  durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 30,
  rank: (json['rank'] as num?)?.toInt(),
  isExplicit: json['isExplicit'] == null
      ? false
      : jsonIsTrue(json['isExplicit']),
  contributors:
      (json['contributors'] as List<dynamic>?)
          ?.map(
            (e) => Contributor.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const [],
  link: json['link'] as String?,
  isrc: jsonStringOrNull(json['isrc']),
);

Map<String, dynamic> _$TrackToJson(_Track instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'artistId': instance.artistId,
  'artistName': instance.artistName,
  'albumId': instance.albumId,
  'albumTitle': instance.albumTitle,
  'coverUrl': instance.coverUrl,
  'previewUrl': instance.previewUrl,
  'durationSeconds': instance.durationSeconds,
  'rank': instance.rank,
  'isExplicit': instance.isExplicit,
  'contributors': instance.contributors.map((e) => e.toJson()).toList(),
  'link': instance.link,
  'isrc': instance.isrc,
};
