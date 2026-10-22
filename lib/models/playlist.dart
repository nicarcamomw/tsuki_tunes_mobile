import 'package:cloud_firestore/cloud_firestore.dart';
import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    this.tracks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get coverUrl => tracks.isNotEmpty ? tracks.first.coverUrl : '';
  int get trackCount => tracks.length;
  int get totalDurationSeconds =>
      tracks.fold(0, (total, t) => total + t.durationSeconds);

  factory Playlist.fromJson(Map<String, dynamic> json) {
    List<Track> tracks = [];
    if (json['tracks'] is List) {
      tracks = (json['tracks'] as List)
          .map((t) => Track.fromStorage(Map<String, dynamic>.from(t)))
          .toList();
    }

    DateTime created = DateTime.now();
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString()) ?? created;
    }

    DateTime updated = DateTime.now();
    if (json['updatedAt'] != null) {
      updated = DateTime.tryParse(json['updatedAt'].toString()) ?? updated;
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      tracks: tracks,
      createdAt: created,
      updatedAt: updated,
    );
  }

  factory Playlist.fromFirestore(Map<String, dynamic> data, {String? docId}) {
    List<Track> tracks = [];
    if (data['tracks'] is List) {
      tracks = (data['tracks'] as List)
          .map((t) => Track.fromStorage(Map<String, dynamic>.from(t)))
          .toList();
    }

    DateTime created = DateTime.now();
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is Map) {
      final sec = rawCreated['seconds'] ?? rawCreated['_seconds'];
      if (sec is num) {
        created = DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
      }
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? created;
    }

    DateTime updated = DateTime.now();
    final rawUpdated = data['updatedAt'];
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is Map) {
      final sec = rawUpdated['seconds'] ?? rawUpdated['_seconds'];
      if (sec is num) {
        updated = DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
      }
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated) ?? updated;
    }

    return Playlist(
      id: docId ?? data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      tracks: tracks,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Playlist copyWith({
    String? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
