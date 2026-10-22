import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tsuki_tunes_mobile/services/firebase_service.dart';

/// FirebaseService backed by an in-memory Firestore, always signed in.
/// Several instances can share one [FakeFirebaseFirestore] to simulate
/// multiple devices of the same user.
class FakeFirebaseService implements FirebaseService {
  FakeFirebaseService(this.db);

  @override
  final FakeFirebaseFirestore db;

  @override
  bool get isSignedIn => true;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Timestamp ts(DateTime d) => Timestamp.fromDate(d);
