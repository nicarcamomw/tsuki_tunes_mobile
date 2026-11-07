import '../entities/party.dart';
import '../entities/track.dart';

/// Listening parties (`parties/{host}`).
abstract interface class PartyRepository {
  Stream<Party?> watch(String host);

  /// Parties I'm invited to, live.
  Stream<List<Party>> watchInvitations(String me);

  /// Opens my party (I host it), with what I'm playing.
  Future<void> open({required String me, required String myName, Track? track, int positionMs, bool playing});

  /// The host tells where the music is.
  Future<void> publish({required String me, Track? track, required int positionMs, required bool playing});

  Future<void> invite({required String me, required String bond});
  Future<void> join({required String host, required String me, required String myName});
  Future<void> decline({required String host, required String me});
  Future<void> leave({required String host, required String me});

  /// The host ends it.
  Future<void> close(String me);
}
