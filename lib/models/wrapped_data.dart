import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_readers.dart';

part 'wrapped_data.freezed.dart';
part 'wrapped_data.g.dart';

@freezed
abstract class WrappedTrackEntry with _$WrappedTrackEntry {
  const factory WrappedTrackEntry({
    @JsonKey(defaultValue: '') required String trackId,
    @JsonKey(defaultValue: '') required String title,
    @JsonKey(defaultValue: '') required String artistName,
    @JsonKey(defaultValue: '') required String albumTitle,
    @JsonKey(defaultValue: '') required String coverUrl,
    @JsonKey(defaultValue: 0) required int playCount,
    @JsonKey(defaultValue: 0) required int totalSeconds,
  }) = _WrappedTrackEntry;

  factory WrappedTrackEntry.fromJson(Map<String, dynamic> json) =>
      _$WrappedTrackEntryFromJson(json);
}

@freezed
abstract class WrappedArtistEntry with _$WrappedArtistEntry {
  const factory WrappedArtistEntry({
    @JsonKey(defaultValue: '') required String name,
    @JsonKey(defaultValue: 0) required int playCount,
    @JsonKey(defaultValue: 0) required int totalSeconds,
    String? coverUrl,
  }) = _WrappedArtistEntry;

  factory WrappedArtistEntry.fromJson(Map<String, dynamic> json) =>
      _$WrappedArtistEntryFromJson(json);
}

@freezed
abstract class WrappedFunFact with _$WrappedFunFact {
  const factory WrappedFunFact({
    @JsonKey(defaultValue: '') required String key,
    @JsonKey(defaultValue: <String, dynamic>{})
    required Map<String, dynamic> data,
  }) = _WrappedFunFact;

  factory WrappedFunFact.fromJson(Map<String, dynamic> json) =>
      _$WrappedFunFactFromJson(json);
}

@freezed
abstract class WrappedData with _$WrappedData {
  const WrappedData._();

  const factory WrappedData({
    @JsonKey(defaultValue: 0) required int year,
    @JsonKey(defaultValue: <WrappedTrackEntry>[])
    required List<WrappedTrackEntry> topTracks,
    @JsonKey(defaultValue: <WrappedArtistEntry>[])
    required List<WrappedArtistEntry> topArtists,
    @JsonKey(defaultValue: 0) required int totalMinutesListened,
    @JsonKey(defaultValue: 0) required int totalTracksPlayed,
    @JsonKey(defaultValue: 0) required int uniqueTracksCount,
    @JsonKey(defaultValue: 0) required int uniqueArtistsCount,
    @JsonKey(defaultValue: 0) required int favoriteHour,
    @JsonKey(defaultValue: <int, int>{})
    required Map<int, int> hourDistribution,
    @JsonKey(defaultValue: <WrappedFunFact>[])
    required List<WrappedFunFact> funFacts,
    @JsonKey(fromJson: jsonDateOrNow) required DateTime generatedAt,

    /// True when built from the per-play log (real play counts). False when
    /// only first listens were available ("discoveries"), where counts would
    /// all be 1 and must not be shown as plays.
    @JsonKey(fromJson: jsonIsTrue) @Default(false) bool basedOnPlays,

    /// First day with recorded plays in [year], when [basedOnPlays].
    @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false)
    DateTime? playsSince,
  }) = _WrappedData;

  factory WrappedData.fromJson(Map<String, dynamic> json) =>
      _$WrappedDataFromJson(json);

  bool get isEmpty => totalTracksPlayed == 0;
}
