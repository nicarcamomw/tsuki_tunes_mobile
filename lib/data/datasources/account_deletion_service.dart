import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logger.dart';

final _log = Log.named('AccountDeletion');

/// Deletes what an account keeps in Firestore, within what firestore.rules
/// allow from the app:
///
/// * Subcollections under the rate limit (listened songs, playlists,
///   followed artists, unmark log) go in batches that stamp the user
///   document's `lastSubWrite`, at most one batch per second.
/// * The daily play log and the public profile are deleted outright.
/// * The user document itself can't be deleted (recreating it would reset
///   the rate limit), so every field but the rate-limit stamp is removed:
///   nothing about the person is left in it.
///
/// Reads come from the server, so a phone offline fails here, before the
/// sign-in account is deleted, instead of leaving data behind.
class AccountDeletionService {
  AccountDeletionService(this._db, {Duration? batchGap})
      : _batchGap = batchGap ?? const Duration(milliseconds: 1100);

  final FirebaseFirestore _db;

  /// Wait between rate-limited batches; the rules ask for over a second.
  final Duration _batchGap;

  static const _rateLimited = [
    'listenedTracks',
    'playlists',
    'followedArtists',
    'listenedDeletions',
  ];
  static const _batchSize = 400;

  /// Fields of the user document; only `lastSubWrite` stays.
  static const _userFields = [
    'displayName',
    'email',
    'photoURL',
    'createdAt',
    'lastLoginAt',
    'stats',
    'masks',
  ];

  Future<void> deleteUserData(String uid) async {
    final user = _db.collection('users').doc(uid);
    for (final name in _rateLimited) {
      while (true) {
        final page = await user
            .collection(name)
            .limit(_batchSize)
            .get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        // Also before the first: the app may have just stamped it.
        await Future<void>.delayed(_batchGap);
        final batch = _db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        batch.set(user, {'lastSubWrite': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await batch.commit();
        if (page.docs.length < _batchSize) break;
      }
    }

    // No rate limit on these.
    while (true) {
      final page = await user
          .collection('playDays')
          .limit(_batchSize)
          .get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (page.docs.length < _batchSize) break;
    }
    await _db.collection('profiles').doc(uid).delete();

    final userDoc = await user.get(const GetOptions(source: Source.server));
    if (userDoc.exists) {
      await user.update({
        for (final f in _userFields) f: FieldValue.delete(),
      });
    }
    _log.info('Firestore data of the account deleted');
  }
}
