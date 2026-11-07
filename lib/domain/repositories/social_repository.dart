import '../entities/public_profile.dart';
import '../entities/social.dart';

/// Bonds (Lazos) between Bearers: finding them, the requests, the Bonds
/// themselves. Every call is for the signed-in user ([me]).
abstract interface class SocialRepository {
  /// Public profiles whose name starts with [query] (any case, accents
  /// ignored), at most [limit].
  Future<List<PublicProfile>> search(String query, {int limit = 15});

  /// My Bonds, live.
  Stream<List<SocialPerson>> watchBonds(String me);

  /// Requests others sent me, live.
  Stream<List<SocialPerson>> watchReceived(String me);

  /// Requests I sent, still unanswered, live.
  Stream<List<SocialPerson>> watchSent(String me);

  /// Asks [to] for a Bond, as [me].
  Future<void> sendRequest({required SocialPerson me, required SocialPerson to});

  /// Takes back my request to [to].
  Future<void> cancelRequest({required String me, required String to});

  /// Accepts [from]'s request: the Bond, on both sides ([me] is my card,
  /// for their list).
  Future<void> accept({required SocialPerson me, required String from});

  /// Turns down [from]'s request.
  Future<void> decline({required String me, required String from});

  /// Undoes the Bond with [other], on both sides.
  Future<void> unbond({required String me, required String other});
}
