import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_environment.dart';
import '../../core/constants/firebase_emulators.dart';
import '../../core/logger.dart';
import '../../firebase_options.dart';
import '../../firebase_options_dev.dart';


final _log = Log.named('Firebase');

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _coreReady = false;
  bool _initialized = false;
  bool _appCheckActive = false;
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  GoogleSignIn? _googleSignIn;
  // google_sign_in 7: initialize() exactly once, before anything else; every
  // Google call awaits it.
  Future<void>? _googleReady;

  bool get isInitialized => _initialized;
  bool get appCheckActive => _appCheckActive;
  FirebaseAuth get auth {
    if (_auth == null) throw StateError('FirebaseService not initialized');
    return _auth!;
  }
  FirebaseFirestore get db {
    if (_db == null) throw StateError('FirebaseService not initialized');
    return _db!;
  }
  GoogleSignIn get googleSignIn {
    if (_googleSignIn == null) throw StateError('FirebaseService not initialized');
    return _googleSignIn!;
  }
  User? get currentUser => _auth?.currentUser;
  bool get isSignedIn => currentUser != null;

  /// Firebase.initializeApp() only — enough for AuthProvider to start
  /// listening. The rest (AppCheck, Crashlytics) runs after the first frame.
  Future<void> initializeCore() async {
    if (_coreReady) return;
    await Firebase.initializeApp(
      // The dev flavor has a Firebase project of its own (tsuki-tunes-dev).
      options: isDevEnvironment
          ? DevFirebaseOptions.android
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (useFirebaseEmulators) {
      // Before anything signs in or reads the session. 127.0.0.1 through
      // adb reverse, so FlutterFire's rewrite to the Android emulator's
      // 10.0.2.2 is turned off.
      await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099,
          automaticHostMapping: false);
      _log.fine('Using the local emulators at $firebaseEmulatorHost');
    }
    _coreReady = true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await initializeCore();
    // The emulators don't check App Check tokens.
    if (!useFirebaseEmulators) await _activateAppCheck();
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
    _db!.settings = const Settings(
      // No disk cache against the emulators: the real project's cache (and
      // its pending writes) is keyed by project, not host, so the two would
      // mix, and an emulator write could later reach the real project.
      persistenceEnabled: !useFirebaseEmulators,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // After the settings above, which would otherwise put the real host back.
    if (useFirebaseEmulators) {
      _db!.useFirestoreEmulator(firebaseEmulatorHost, 8080,
          automaticHostMapping: false);
    }
    _googleSignIn = GoogleSignIn.instance;
    _googleReady ??= _googleSignIn!.initialize(
      // In dev, null: Android takes the dev project's web client from its
      // google-services.json (default_web_client_id).
      serverClientId: isDevEnvironment
          ? null
          : '812277566403-sre5ujppbo4vk71qrvjcdgffcuhd0ro9.apps.googleusercontent.com',
    );
    _initialized = true;
  }

  /// Attaches App Check tokens to Firebase requests. This alone blocks
  /// nothing: enforcement is switched on per service in the Firebase console.
  /// Debug builds use the debug provider; its token is printed in logcat
  /// ("Enter this debug secret into the allow list…") and must be added in
  /// the console before enforcing, or debug builds lose Firestore access.
  Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      _appCheckActive = true;
    } catch (e) {
      _appCheckActive = false;
      _log.warning('App Check activation failed (non-fatal): $e');
    }
  }

  /// The account chosen in Google's picker, or null when the person
  /// cancelled or closed it (google_sign_in 7 throws for that).
  Future<GoogleSignInAccount?> _pickGoogleAccount() async {
    await _googleReady;
    try {
      return await _googleSignIn!.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Firebase only needs Google's ID token (the email comes in it).
  static OAuthCredential _credentialFor(GoogleSignInAccount account) =>
      GoogleAuthProvider.credential(idToken: account.authentication.idToken);

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleReady;
      await _googleSignIn?.signOut();
    } catch (_) {}

    final googleUser = await _pickGoogleAccount();
    if (googleUser == null) {
      // User cancelled or closed the picker
      return null;
    }

    final credential = _credentialFor(googleUser);

    final userCredential = await _auth!.signInWithCredential(credential);
    try {
      if (userCredential.user != null) {
        await _syncUserProfile(userCredential.user!);
      }
    } catch (e) {
      // Non-blocking: Firestore permission/network errors shouldn't break sign-in
      _log.warning('Firestore profile sync non-fatal warning: $e');
    }
    return userCredential;
  }

  Future<void> _syncUserProfile(User user) async {
    final docRef = _db!.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'stats': {'totalTracks': 0},
      });
    } else {
      await docRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Signs in with Google again to prove it's still the owner, which
  /// Firebase asks before deleting an account. Uses the Google account
  /// already on the phone when it can, otherwise shows the picker. False
  /// when the person cancelled; throws when another Google account was
  /// picked or sign-in failed.
  Future<bool> reauthenticateWithGoogle() async {
    final user = _auth?.currentUser;
    if (user == null) return false;
    await _googleReady;
    GoogleSignInAccount? account;
    try {
      // May show a quick account sheet on Android (google_sign_in 7).
      account = await _googleSignIn!.attemptLightweightAuthentication();
    } catch (_) {}
    account ??= await _pickGoogleAccount();
    if (account == null) return false;
    await user.reauthenticateWithCredential(_credentialFor(account));
    return true;
  }

  /// Deletes the signed-in Firebase account (which also signs it out) and
  /// forgets the Google account on this phone.
  Future<void> deleteCurrentUser() async {
    final user = _auth?.currentUser;
    if (user == null) return;
    await user.delete();
    try {
      await _googleSignIn?.disconnect();
    } catch (e) {
      _log.warning('Google disconnect failed (non-fatal): $e');
      try {
        await _googleSignIn?.signOut();
      } catch (_) {}
    }
    await _auth?.signOut();
  }

  /// Signs out of Firebase even when Google's own sign-out fails (offline,
  /// Play services hiccup), so a failed logout never leaves the account on.
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      _log.warning('Google sign-out failed (non-fatal): $e');
    }
    await _auth?.signOut();
  }
}
