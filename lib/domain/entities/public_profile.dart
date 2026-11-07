import 'social.dart';

/// What a user shows of themselves: the numbers of their library and the
/// artists they listen to most. Nothing else of theirs is in it.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.maskId,
    this.isPublic = false,
    this.stats = const ProfileStats(),
    this.topArtists = const [],
    this.tops = const [],
    this.milestones = const [],
    this.updatedAt,
  });

  /// Longest name the server takes (firestore.rules).
  static const maxNameLength = 60;

  /// How many top artists it shows.
  static const topArtistsShown = 5;

  final String uid;
  final String displayName;
  final String? photoUrl;

  /// The oni mask they have equipped, if any.
  final String? maskId;

  /// Whether anyone with the link may see it (only its owner otherwise).
  final bool isPublic;
  final ProfileStats stats;
  final List<TopArtist> topArtists;

  /// The most listened artists' names, best first (up to
  /// Sintonia.artistsCompared), for the Sintonía with others.
  final List<String> tops;

  /// What their Echo did lately, newest first (Resonances).
  final List<Milestone> milestones;
  final DateTime? updatedAt;

  PublicProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? maskId,
    bool? isPublic,
    ProfileStats? stats,
    List<TopArtist>? topArtists,
    List<String>? tops,
    List<Milestone>? milestones,
  }) =>
      PublicProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        maskId: maskId ?? this.maskId,
        isPublic: isPublic ?? this.isPublic,
        stats: stats ?? this.stats,
        topArtists: topArtists ?? this.topArtists,
        tops: tops ?? this.tops,
        milestones: milestones ?? this.milestones,
        updatedAt: updatedAt,
      );

  /// Whether publishing this would change what others see (the time aside).
  bool sameContentAs(PublicProfile other) =>
      displayName == other.displayName &&
      photoUrl == other.photoUrl &&
      maskId == other.maskId &&
      isPublic == other.isPublic &&
      stats == other.stats &&
      _sameArtists(topArtists, other.topArtists) &&
      _same(tops, other.tops) &&
      _same(milestones, other.milestones);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameArtists(List<TopArtist> a, List<TopArtist> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ProfileStats {
  const ProfileStats({this.tracks = 0, this.albums = 0, this.artists = 0});

  /// Songs marked as listened, albums fully listened, distinct artists.
  final int tracks;
  final int albums;
  final int artists;

  @override
  bool operator ==(Object other) =>
      other is ProfileStats && other.tracks == tracks && other.albums == albums && other.artists == artists;

  @override
  int get hashCode => Object.hash(tracks, albums, artists);
}

class TopArtist {
  const TopArtist({required this.name, required this.count, this.pictureUrl});

  final String name;

  /// Songs of theirs listened.
  final int count;
  final String? pictureUrl;

  @override
  bool operator ==(Object other) =>
      other is TopArtist && other.name == name && other.count == count && other.pictureUrl == pictureUrl;

  @override
  int get hashCode => Object.hash(name, count, pictureUrl);
}
