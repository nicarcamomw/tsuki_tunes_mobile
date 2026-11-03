// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wrapped_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WrappedTrackEntry _$WrappedTrackEntryFromJson(Map json) => _WrappedTrackEntry(
  trackId: json['trackId'] as String? ?? '',
  title: json['title'] as String? ?? '',
  artistName: json['artistName'] as String? ?? '',
  albumTitle: json['albumTitle'] as String? ?? '',
  coverUrl: json['coverUrl'] as String? ?? '',
  playCount: (json['playCount'] as num?)?.toInt() ?? 0,
  totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WrappedTrackEntryToJson(_WrappedTrackEntry instance) =>
    <String, dynamic>{
      'trackId': instance.trackId,
      'title': instance.title,
      'artistName': instance.artistName,
      'albumTitle': instance.albumTitle,
      'coverUrl': instance.coverUrl,
      'playCount': instance.playCount,
      'totalSeconds': instance.totalSeconds,
    };

_WrappedArtistEntry _$WrappedArtistEntryFromJson(Map json) =>
    _WrappedArtistEntry(
      name: json['name'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl'] as String?,
    );

Map<String, dynamic> _$WrappedArtistEntryToJson(_WrappedArtistEntry instance) =>
    <String, dynamic>{
      'name': instance.name,
      'playCount': instance.playCount,
      'totalSeconds': instance.totalSeconds,
      'coverUrl': instance.coverUrl,
    };

_WrappedAlbumEntry _$WrappedAlbumEntryFromJson(Map json) => _WrappedAlbumEntry(
  albumId: json['albumId'] as String? ?? '',
  title: json['title'] as String? ?? '',
  artistName: json['artistName'] as String? ?? '',
  coverUrl: json['coverUrl'] as String? ?? '',
  playCount: (json['playCount'] as num?)?.toInt() ?? 0,
  trackIds:
      (json['trackIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WrappedAlbumEntryToJson(_WrappedAlbumEntry instance) =>
    <String, dynamic>{
      'albumId': instance.albumId,
      'title': instance.title,
      'artistName': instance.artistName,
      'coverUrl': instance.coverUrl,
      'playCount': instance.playCount,
      'trackIds': instance.trackIds,
      'totalTracks': instance.totalTracks,
    };

_WrappedFunFact _$WrappedFunFactFromJson(Map json) => _WrappedFunFact(
  key: json['key'] as String? ?? '',
  data: (json['data'] as Map?)?.map((k, e) => MapEntry(k as String, e)) ?? {},
);

Map<String, dynamic> _$WrappedFunFactToJson(_WrappedFunFact instance) =>
    <String, dynamic>{'key': instance.key, 'data': instance.data};

_WrappedData _$WrappedDataFromJson(Map json) => _WrappedData(
  year: (json['year'] as num?)?.toInt() ?? 0,
  month: (json['month'] as num?)?.toInt(),
  activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
  periodDays: (json['periodDays'] as num?)?.toInt() ?? 0,
  previousMinutes: (json['previousMinutes'] as num?)?.toInt(),
  topTracks:
      (json['topTracks'] as List<dynamic>?)
          ?.map(
            (e) =>
                WrappedTrackEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      [],
  topArtists:
      (json['topArtists'] as List<dynamic>?)
          ?.map(
            (e) => WrappedArtistEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      [],
  totalMinutesListened: (json['totalMinutesListened'] as num?)?.toInt() ?? 0,
  totalTracksPlayed: (json['totalTracksPlayed'] as num?)?.toInt() ?? 0,
  uniqueTracksCount: (json['uniqueTracksCount'] as num?)?.toInt() ?? 0,
  uniqueArtistsCount: (json['uniqueArtistsCount'] as num?)?.toInt() ?? 0,
  favoriteHour: (json['favoriteHour'] as num?)?.toInt() ?? 0,
  hourDistribution:
      (json['hourDistribution'] as Map?)?.map(
        (k, e) => MapEntry(int.parse(k as String), (e as num).toInt()),
      ) ??
      {},
  funFacts:
      (json['funFacts'] as List<dynamic>?)
          ?.map(
            (e) => WrappedFunFact.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      [],
  generatedAt: jsonDateOrNow(json['generatedAt']),
  basedOnPlays: json['basedOnPlays'] == null
      ? false
      : jsonIsTrue(json['basedOnPlays']),
  playsSince: jsonDateOrNull(json['playsSince']),
  topAlbums:
      (json['topAlbums'] as List<dynamic>?)
          ?.map(
            (e) =>
                WrappedAlbumEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <WrappedAlbumEntry>[],
  completedAlbums:
      (json['completedAlbums'] as List<dynamic>?)
          ?.map(
            (e) =>
                WrappedAlbumEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <WrappedAlbumEntry>[],
  longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
  streakStart: jsonDateOrNull(json['streakStart']),
);

Map<String, dynamic> _$WrappedDataToJson(
  _WrappedData instance,
) => <String, dynamic>{
  'year': instance.year,
  'month': ?instance.month,
  'activeDays': instance.activeDays,
  'periodDays': instance.periodDays,
  'previousMinutes': ?instance.previousMinutes,
  'topTracks': instance.topTracks.map((e) => e.toJson()).toList(),
  'topArtists': instance.topArtists.map((e) => e.toJson()).toList(),
  'totalMinutesListened': instance.totalMinutesListened,
  'totalTracksPlayed': instance.totalTracksPlayed,
  'uniqueTracksCount': instance.uniqueTracksCount,
  'uniqueArtistsCount': instance.uniqueArtistsCount,
  'favoriteHour': instance.favoriteHour,
  'hourDistribution': instance.hourDistribution.map(
    (k, e) => MapEntry(k.toString(), e),
  ),
  'funFacts': instance.funFacts.map((e) => e.toJson()).toList(),
  'generatedAt': instance.generatedAt.toIso8601String(),
  'basedOnPlays': instance.basedOnPlays,
  'playsSince': ?instance.playsSince?.toIso8601String(),
  'topAlbums': instance.topAlbums.map((e) => e.toJson()).toList(),
  'completedAlbums': instance.completedAlbums.map((e) => e.toJson()).toList(),
  'longestStreak': instance.longestStreak,
  'streakStart': ?instance.streakStart?.toIso8601String(),
};
