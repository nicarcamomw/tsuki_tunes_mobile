import 'package:cloud_firestore/cloud_firestore.dart';

import 'outbox.dart';

/// Firestore errors that a retry can't fix: the rules refused the write,
/// the data is invalid, or the document a write needs is gone.
const _permanentCodes = {
  'permission-denied',
  'invalid-argument',
  'not-found',
  'failed-precondition',
  'out-of-range',
  'unauthenticated',
};

/// Runs a Firestore write for the outbox: a refusal for good becomes a
/// [PermanentSyncError] (the change is undone), anything else (offline,
/// unavailable, rate limits, timeouts) is retried later.
Future<void> sendToFirestore(Future<void> Function() write) async {
  try {
    await write();
  } on FirebaseException catch (e) {
    if (_permanentCodes.contains(e.code)) throw PermanentSyncError(e.code);
    rethrow;
  }
}
