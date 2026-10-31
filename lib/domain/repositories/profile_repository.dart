import '../entities/public_profile.dart';

/// Public profiles. Others' profiles read as null when they don't exist or
/// are private.
abstract interface class ProfileRepository {
  Future<PublicProfile?> getProfile(String uid);
  Stream<PublicProfile?> watchProfile(String uid);

  /// Publishes the signed-in user's own profile.
  Future<void> saveMyProfile(PublicProfile profile);
}
