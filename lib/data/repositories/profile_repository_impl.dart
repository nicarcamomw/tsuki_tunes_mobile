import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/public_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/firebase_service.dart';
import '../mappers/profile_firestore.dart';

/// Profiles in `profiles/{uid}`, public data only (the rules check every
/// field and let others read it only when public).
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._firebase);

  final FirebaseService _firebase;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firebase.db.collection('profiles').doc(uid);

  @override
  Future<PublicProfile?> getProfile(String uid) async {
    try {
      final snap = await _doc(uid).get();
      final data = snap.data();
      return data == null ? null : profileFromFirestore(uid, data);
    } on FirebaseException catch (e) {
      // Private (or not ours to read): as if it weren't there.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Stream<PublicProfile?> watchProfile(String uid) => _doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? null : profileFromFirestore(uid, data);
      })
      .handleError((Object e) {}, test: (e) => e is FirebaseException && e.code == 'permission-denied');

  @override
  Future<void> saveMyProfile(PublicProfile profile) => _doc(profile.uid).set(profileToFirestore(profile));
}
