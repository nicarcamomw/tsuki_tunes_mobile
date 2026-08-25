import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  GoogleSignIn? _googleSignIn;

  bool get isInitialized => _initialized;
  FirebaseAuth get auth => _auth!;
  FirebaseFirestore get db => _db!;
  GoogleSignIn get googleSignIn => _googleSignIn!;
  User? get currentUser => _auth?.currentUser;

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
    _googleSignIn = GoogleSignIn(
      serverClientId: '812277566403-sre5ujppbo4vk71qrvjcdgffcuhd0ro9.apps.googleusercontent.com',
    );
    _initialized = true;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth!.signInWithCredential(credential);
    await _syncUserProfile(userCredential.user!);
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

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth?.signOut();
  }
}
