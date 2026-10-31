import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Reads `users/{uid}/playlists/{docId}`, whose dates are Firestore
  /// timestamps (or, from older clients, seconds maps or ISO strings).
  factory Playlist.fromFirestore(Map<String, dynamic> data, {String? docId}) {
    List<Track> tracks = [];
    if (data['tracks'] is List) {
      tracks = (data['tracks'] as List)
          .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
          .toList();
    }

    return Playlist(
      id: docId ?? data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      tracks: tracks,
      createdAt: _firestoreDate(data['createdAt']),
      updatedAt: _firestoreDate(data['updatedAt']),
    );
  }

  String get coverUrl => tracks.isNotEmpty ? tracks.first.coverUrl : '';
  int get trackCount => tracks.length;
  int get totalDurationSeconds =>
      tracks.fold(0, (total, t) => total + t.durationSeconds);

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

DateTime _firestoreDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is Map) {
    final sec = raw['seconds'] ?? raw['_seconds'];
    if (sec is num) {
      return DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
    }
  } else if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}
