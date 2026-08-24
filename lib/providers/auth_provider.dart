import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();

  User? _user;
  bool _loading = true;
  StreamSubscription<User?>? _authSub;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get uid => _user?.uid;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _firebase.initialize();
      _authSub = _firebase.auth.authStateChanges().listen((user) {
        _user = user;
        _loading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Firebase init error: $e');
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      final result = await _firebase.signInWithGoogle();
      return result != null;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _firebase.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
