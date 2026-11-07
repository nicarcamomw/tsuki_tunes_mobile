import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/public_profile.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/firebase_service.dart';
import '../mappers/profile_firestore.dart';

/// Bonds in Firestore (firestore.rules checks each write):
/// - `users/{uid}/friendRequests/{from}`: requests others sent me, written
///   by the sender.
/// - `users/{uid}/sentRequests/{to}`: the ones I sent, mine only.
/// - `users/{uid}/friends/{other}`: my Bonds; the one who accepts writes
///   both sides, while the request still exists.
/// Each document carries the other person's name, photo and mask, so the
/// lists need no profile reads.
class SocialRepositoryImpl implements SocialRepository {
  SocialRepositoryImpl(this._firebase);

  final FirebaseService _firebase;

  FirebaseFirestore get _db => _firebase.db;
  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _col(String uid, String name) => _user(uid).collection(name);

  static Map<String, Object?> _card(SocialPerson p) => {
        'name': p.name.length > PublicProfile.maxNameLength ? p.name.substring(0, PublicProfile.maxNameLength) : p.name,
        'photoUrl': p.photoUrl,
        'maskId': p.maskId,
        'at': FieldValue.serverTimestamp(),
      };

  static SocialPerson _person(String uid, Map<String, dynamic> d) => SocialPerson(
        uid: uid,
        name: d['name'] is String && (d['name'] as String).isNotEmpty ? d['name'] as String : 'Tsuki',
        photoUrl: d['photoUrl'] is String ? d['photoUrl'] as String : null,
        maskId: d['maskId'] is String ? d['maskId'] as String : null,
        at: d['at'] is Timestamp ? (d['at'] as Timestamp).toDate() : null,
      );

  Stream<List<SocialPerson>> _watch(String uid, String name) => _col(uid, name)
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) _person(d.id, d.data())]);

  @override
  Future<List<PublicProfile>> search(String query, {int limit = 15}) async {
    final key = profileSearchKey(query);
    if (key.isEmpty) return const [];
    final snap = await _db
        .collection('profiles')
        .where('public', isEqualTo: true)
        .where('nameLower', isGreaterThanOrEqualTo: key)
        .where('nameLower', isLessThan: '$key')
        .orderBy('nameLower')
        .limit(limit)
        .get();
    return [for (final d in snap.docs) profileFromFirestore(d.id, d.data())];
  }

  @override
  Stream<List<SocialPerson>> watchBonds(String me) => _watch(me, 'friends');

  @override
  Stream<List<SocialPerson>> watchReceived(String me) => _watch(me, 'friendRequests');

  @override
  Stream<List<SocialPerson>> watchSent(String me) => _watch(me, 'sentRequests');

  @override
  Future<void> sendRequest({required SocialPerson me, required SocialPerson to}) async {
    // The stamp keeps it to one request a second (the rules check it).
    final batch = _db.batch()
      ..set(_col(to.uid, 'friendRequests').doc(me.uid), _card(me))
      ..set(_col(me.uid, 'sentRequests').doc(to.uid), _card(to))
      ..set(_user(me.uid), {'lastSubWrite': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> cancelRequest({required String me, required String to}) async {
    final batch = _db.batch()
      ..delete(_col(me, 'sentRequests').doc(to))
      ..delete(_col(to, 'friendRequests').doc(me));
    await batch.commit();
  }

  @override
  Future<void> accept({required SocialPerson me, required String from}) async {
    final meCard = me;
    final uid = me.uid;
    final request = await _col(uid, 'friendRequests').doc(from).get();
    final mine = await _col(uid, 'sentRequests').doc(from).get();
    if (!request.exists) return;
    final them = _person(from, request.data()!);
    final batch = _db.batch()
      ..set(_col(uid, 'friends').doc(from), _card(them))
      ..set(_col(from, 'friends').doc(uid), _card(meCard))
      ..delete(_col(uid, 'friendRequests').doc(from))
      ..delete(_col(from, 'sentRequests').doc(uid));
    // Both had asked each other: my request to them goes too.
    if (mine.exists) {
      batch
        ..delete(_col(uid, 'sentRequests').doc(from))
        ..delete(_col(from, 'friendRequests').doc(uid));
    }
    await batch.commit();
  }

  @override
  Future<void> decline({required String me, required String from}) async {
    final batch = _db.batch()
      ..delete(_col(me, 'friendRequests').doc(from))
      ..delete(_col(from, 'sentRequests').doc(me));
    await batch.commit();
  }

  @override
  Future<void> unbond({required String me, required String other}) async {
    final batch = _db.batch()
      ..delete(_col(me, 'friends').doc(other))
      ..delete(_col(other, 'friends').doc(me));
    await batch.commit();
  }
}
