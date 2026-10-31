// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Playlist _$PlaylistFromJson(Map json) => _Playlist(
  id: jsonString(json['id']),
  name: jsonString(json['name']),
  tracks:
      (json['tracks'] as List<dynamic>?)
          ?.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ??
      const [],
  createdAt: jsonDateOrNow(json['createdAt']),
  updatedAt: jsonDateOrNow(json['updatedAt']),
);

Map<String, dynamic> _$PlaylistToJson(_Playlist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'tracks': instance.tracks.map((e) => e.toJson()).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
