import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_readers.dart';
import 'track.dart';

part 'playlist.freezed.dart';
part 'playlist.g.dart';

@freezed
abstract class Playlist with _$Playlist {
  const Playlist._();

  const factory Playlist({
    @JsonKey(fromJson: jsonString) required String id,
    @JsonKey(fromJson: jsonString) required String name,
    @Default([]) List<Track> tracks,
    @JsonKey(fromJson: jsonDateOrNow) required DateTime createdAt,
    @JsonKey(fromJson: jsonDateOrNow) required DateTime updatedAt,
  }) = _Playlist;

  /// Reads the local JSON written by [toJson].
  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  /// The most songs a playlist holds (the Firestore document has to fit
  /// in its 1 MiB limit).
  static const int maxTracks = 1000;

  bool get isFull => tracks.length >= maxTracks;
  bool contains(String trackId) => tracks.any((t) => t.id == trackId);

  String get coverUrl => tracks.isNotEmpty ? tracks.first.coverUrl : '';
  int get trackCount => tracks.length;
  int get totalDurationSeconds =>
      tracks.fold(0, (total, t) => total + t.durationSeconds);

}
