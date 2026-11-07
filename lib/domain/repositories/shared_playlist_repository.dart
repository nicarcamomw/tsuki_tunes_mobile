import '../entities/shared_playlist.dart';
import '../entities/track.dart';

/// Collaborative playlists. Every call acts as the signed-in user [me].
abstract interface class SharedPlaylistRepository {
  /// The ones I'm a member of, live.
  Stream<List<SharedPlaylist>> watchMine(String me);

  /// The ones I'm invited to, live.
  Stream<List<SharedPlaylist>> watchInvitations(String me);

  Stream<SharedPlaylist?> watch(String id);

  /// A new one, with me as its owner and only member.
  Future<String> create({required String me, required String myName, required String name, List<Track> tracks});

  Future<void> addTrack({required String id, required String me, required Track track});
  Future<void> removeTrack({required String id, required String me, required String trackId});

  /// The owner invites a Bond.
  Future<void> invite({required String id, required String me, required String bond});

  /// The owner takes back an invitation or removes a member.
  Future<void> removePerson({required String id, required String me, required String uid});

  Future<void> join({required String id, required String me, required String myName});
  Future<void> decline({required String id, required String me});
  Future<void> leave({required String id, required String me});
  Future<void> rename({required String id, required String me, required String name});

  /// Only the owner.
  Future<void> delete(String id);
}
