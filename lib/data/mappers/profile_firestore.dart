import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/public_profile.dart';
import '../../domain/entities/social.dart';
import '../../domain/logic/search_suggestions.dart';
import '../../domain/logic/sintonia.dart';

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
    tops: [
      if (d['tops'] is List)
        for (final t in d['tops'] as List)
          if (t is String) t,
    ],
    milestones: [
      if (d['milestones'] is List)
        for (final m in d['milestones'] as List)
          if (Milestone.fromMap(m) case final ms?) ms,
    ],
    updatedAt: d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null,
  );
}

/// The name as search compares it: lower case, no accents.
String profileSearchKey(String name) {
  final folded = SearchSuggestions.fold(name);
  return folded.length > PublicProfile.maxNameLength ? folded.substring(0, PublicProfile.maxNameLength) : folded;
}

/// The document the rules accept: exactly these fields, the time stamped by
/// the server.
Map<String, dynamic> profileToFirestore(PublicProfile p) => {
      'displayName': p.displayName.length > PublicProfile.maxNameLength
          ? p.displayName.substring(0, PublicProfile.maxNameLength)
          : p.displayName,
      'photoUrl': p.photoUrl,
      'maskId': p.maskId,
      'nameLower': profileSearchKey(p.displayName),
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
      'tops': [
        for (final t in p.tops.take(Sintonia.artistsCompared)) t.length > 200 ? t.substring(0, 200) : t,
      ],
      'milestones': [for (final m in p.milestones.take(Milestone.kept)) m.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    };
