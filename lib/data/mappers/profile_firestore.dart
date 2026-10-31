import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/public_profile.dart';

/// Reads `profiles/{uid}`.
PublicProfile profileFromFirestore(String uid, Map<String, dynamic> d) {
  final stats = d['stats'] is Map ? Map<String, dynamic>.from(d['stats'] as Map) : const <String, dynamic>{};
  int n(Object? v) => v is num ? v.toInt() : 0;
  return PublicProfile(
    uid: uid,
    displayName: d['displayName']?.toString() ?? '',
    photoUrl: d['photoUrl']?.toString(),
    maskId: d['maskId']?.toString(),
    isPublic: d['public'] == true,
    stats: ProfileStats(tracks: n(stats['tracks']), albums: n(stats['albums']), artists: n(stats['artists'])),
    topArtists: [
      if (d['topArtists'] is List)
        for (final a in d['topArtists'] as List)
          if (a is Map && a['name'] is String)
            TopArtist(name: a['name'] as String, count: n(a['count']), pictureUrl: a['pictureUrl']?.toString()),
    ],
    updatedAt: d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null,
  );
}

/// The document the rules accept: exactly these fields, the time stamped by
/// the server.
Map<String, dynamic> profileToFirestore(PublicProfile p) => {
      'displayName': p.displayName.length > PublicProfile.maxNameLength
          ? p.displayName.substring(0, PublicProfile.maxNameLength)
          : p.displayName,
      'photoUrl': p.photoUrl,
      'maskId': p.maskId,
      'public': p.isPublic,
      'stats': {'tracks': p.stats.tracks, 'albums': p.stats.albums, 'artists': p.stats.artists},
      'topArtists': [
        for (final a in p.topArtists.take(PublicProfile.topArtistsShown))
          {
            'name': a.name.length > 200 ? a.name.substring(0, 200) : a.name,
            'count': a.count,
            if (a.pictureUrl != null) 'pictureUrl': a.pictureUrl,
          },
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    };
