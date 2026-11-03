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

/// An album of the period: plays of its songs, and which of them were heard.
@freezed
abstract class WrappedAlbumEntry with _$WrappedAlbumEntry {
  const WrappedAlbumEntry._();

  const factory WrappedAlbumEntry({
    @JsonKey(defaultValue: '') required String albumId,
    @JsonKey(defaultValue: '') required String title,
    @JsonKey(defaultValue: '') required String artistName,
    @JsonKey(defaultValue: '') required String coverUrl,
    @JsonKey(defaultValue: 0) required int playCount,

    /// The album's songs that were heard (ids).
    @Default(<String>[]) List<String> trackIds,

    /// Songs on the album, once known from the catalog (0 = unknown).
    @Default(0) int totalTracks,
  }) = _WrappedAlbumEntry;

  factory WrappedAlbumEntry.fromJson(Map<String, dynamic> json) =>
      _$WrappedAlbumEntryFromJson(json);

  int get tracksHeard => trackIds.length;
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

    /// 1–12 for a monthly recap; null for the whole year.
    @JsonKey(includeIfNull: false) int? month,

    /// Days with music in the period, and how many days it has had so far.
    @Default(0) int activeDays,
    @Default(0) int periodDays,

    /// Minutes in the period before (last month or last year), to compare;
    /// null when unknown.
    @JsonKey(includeIfNull: false) int? previousMinutes,
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

    /// Most-played albums (two or more of their songs heard).
    @Default(<WrappedAlbumEntry>[]) List<WrappedAlbumEntry> topAlbums,

    /// Albums whose every song was heard in the period; filled after a
    /// catalog lookup (see WrappedService.withCompletedAlbums).
    @Default(<WrappedAlbumEntry>[]) List<WrappedAlbumEntry> completedAlbums,

    /// Most days in a row with music, and the first of them.
    @Default(0) int longestStreak,
    @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false)
    DateTime? streakStart,
  }) = _WrappedData;

  factory WrappedData.fromJson(Map<String, dynamic> json) =>
      _$WrappedDataFromJson(json);

  bool get isEmpty => totalTracksPlayed == 0;
  bool get isMonthly => month != null;

  WrappedData withPreviousMinutes(int? minutes) =>
      copyWith(previousMinutes: minutes);
}
