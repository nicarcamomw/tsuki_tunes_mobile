// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Album _$AlbumFromJson(Map json) => _Album(
  id: jsonString(json['id']),
  title: json['title'] as String? ?? 'Unknown Album',
  coverUrl: json['coverUrl'] as String? ?? '',
  coverXl: json['coverXl'] as String?,
  artistId: jsonString(json['artistId']),
  artistName: json['artistName'] as String? ?? 'Unknown Artist',
  releaseDate: json['releaseDate'] as String? ?? '',
  recordType: json['recordType'] as String? ?? 'album',
  fansCount: (json['fansCount'] as num?)?.toInt() ?? 0,
  tracksCount: (json['tracksCount'] as num?)?.toInt() ?? 0,
  link: json['link'] as String?,
  tracks:
      (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      const [],
);

Map<String, dynamic> _$AlbumToJson(_Album instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'coverUrl': instance.coverUrl,
  'coverXl': instance.coverXl,
  'artistId': instance.artistId,
  'artistName': instance.artistName,
  'releaseDate': instance.releaseDate,
  'recordType': instance.recordType,
  'fansCount': instance.fansCount,
  'tracksCount': instance.tracksCount,
  'link': instance.link,
  'tracks': ?_tracksToJson(instance.tracks),
};
