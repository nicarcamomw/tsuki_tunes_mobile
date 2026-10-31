import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

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
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _coreReady = true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await initializeCore();
    await _activateAppCheck();
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
    _db!.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _googleSignIn = GoogleSignIn(
      serverClientId: '812277566403-sre5ujppbo4vk71qrvjcdgffcuhd0ro9.apps.googleusercontent.com',
      scopes: ['email'],
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
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
      _appCheckActive = true;
    } catch (e) {
      _appCheckActive = false;
      debugPrint('App Check activation failed (non-fatal): $e');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) {
      // User cancelled or closed the picker
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth!.signInWithCredential(credential);
    try {
      if (userCredential.user != null) {
        await _syncUserProfile(userCredential.user!);
      }
    } catch (e) {
      // Non-blocking: Firestore permission/network errors shouldn't break sign-in
      debugPrint('Firestore profile sync non-fatal warning: $e');
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

  /// Signs out of Firebase even when Google's own sign-out fails (offline,
  /// Play services hiccup), so a failed logout never leaves the account on.
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed (non-fatal): $e');
    }
    await _auth?.signOut();
  }
}
