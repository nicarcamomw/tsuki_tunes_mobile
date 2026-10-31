import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';

/// Reads `users/{uid}/playlists/{docId}`, whose dates are Firestore
/// timestamps (or, from older clients, seconds maps or ISO strings).
Playlist playlistFromFirestore(Map<String, dynamic> data, {String? docId}) {
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

/// The Firestore document for a playlist; the server stamps updatedAt.
extension PlaylistFirestore on Playlist {
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
