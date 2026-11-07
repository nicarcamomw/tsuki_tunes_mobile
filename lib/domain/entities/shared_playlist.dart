import 'track.dart';

/// A song in a collaborative playlist, with who added it.
class SharedTrack {
  const SharedTrack({required this.track, required this.addedBy});

  final Track track;

  /// The uid of the member who added it.
  final String addedBy;
}

/// A playlist several Bonds edit together. Its owner invites Bonds (one by
/// one), and each invited one joins or declines; every member adds and
/// removes songs.
class SharedPlaylist {
  const SharedPlaylist({
    required this.id,
    required this.name,
    required this.owner,
    required this.members,
    required this.invited,
    required this.names,
    required this.tracks,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String owner;
  final List<String> members;
  final List<String> invited;

  /// uid -> name, for every member (and the owner).
  final Map<String, String> names;
  final List<SharedTrack> tracks;
  final DateTime? updatedAt;

  static const maxTracks = 500;
  static const maxMembers = 20;

  String nameOf(String uid) => names[uid] ?? '?';
  bool isMember(String uid) => members.contains(uid);
  bool isInvited(String uid) => invited.contains(uid);
  String get coverUrl => tracks.isEmpty ? '' : tracks.first.track.coverUrl;
}
