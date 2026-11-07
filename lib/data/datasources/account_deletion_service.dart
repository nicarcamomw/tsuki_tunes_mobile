import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/logger.dart';
import 'audio_precache_service.dart';
import 'deezer_disk_cache.dart';
import 'home_widget_service.dart';
import 'style_service.dart';

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

    await _deleteBonds(uid);

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
    // The level 100 report, if there was one.
    await _db.collection('ascensions').doc(uid).delete();

    final userDoc = await user.get(const GetOptions(source: Source.server));
    if (userDoc.exists) {
      await user.update({
        for (final f in _userFields) f: FieldValue.delete(),
      });
    }
    _log.info('Firestore data of the account deleted');
  }

  /// Bonds and requests, on both sides: my Bonds lose me, my requests leave
  /// their inboxes, the ones I got leave their senders' outboxes.
  Future<void> _deleteBonds(String uid) async {
    final user = _db.collection('users').doc(uid);
    // (my collection, where the other person keeps me)
    const pairs = [
      ('friends', 'friends'),
      ('sentRequests', 'friendRequests'),
      ('friendRequests', 'sentRequests'),
    ];
    for (final (mine, theirs) in pairs) {
      while (true) {
        final page = await user.collection(mine).limit(200).get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in page.docs) {
          batch
            ..delete(doc.reference)
            ..delete(_db.collection('users').doc(doc.id).collection(theirs).doc(uid));
        }
        await batch.commit();
        if (page.docs.length < 200) break;
      }
    }
  }

  /// What else on the phone tells what the person listened to: the saved
  /// song previews and catalog answers, scheduled notifications (Time
  /// Machine, release radar) and the home screen player. Each is best
  /// effort; none can stop the deletion.
  static Future<void> clearDeviceTraces() async {
    Future<void> attempt(String what, Future<void> Function() step) async {
      try {
        await step();
      } catch (e) {
        _log.warning('clearing $what failed: $e');
      }
    }

    await attempt('the song previews', () async => AudioPrecacheService().clearCache());
    await attempt('the catalog cache', DeezerDiskCache().clear);
    await attempt('the artist styles', StyleService.shared.clear);
    await attempt('notifications', FlutterLocalNotificationsPlugin().cancelAll);
    await attempt('the home screen player',
        () => HomeWidgetService().updateTrack(null, isPlaying: false));
  }
}
