// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Artist _$ArtistFromJson(Map json) => _Artist(
  id: jsonString(json['id']),
  name: json['name'] as String? ?? 'Unknown Artist',
  pictureUrl: json['pictureUrl'] as String? ?? '',
  pictureSmall: json['pictureSmall'] as String?,
  pictureMedium: json['pictureMedium'] as String?,
  pictureBig: json['pictureBig'] as String?,
  pictureXl: json['pictureXl'] as String?,
  fansCount: (json['fansCount'] as num?)?.toInt() ?? 0,
  albumsCount: (json['albumsCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ArtistToJson(_Artist instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'pictureUrl': instance.pictureUrl,
  'pictureSmall': instance.pictureSmall,
  'pictureMedium': instance.pictureMedium,
  'pictureBig': instance.pictureBig,
  'pictureXl': instance.pictureXl,
  'fansCount': instance.fansCount,
  'albumsCount': instance.albumsCount,
};
