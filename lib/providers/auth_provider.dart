import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();

  User? _user;
  bool _isGuest = false;
  bool _loading = true;
  String? _authError;
  bool _wasCancelled = false;
  StreamSubscription<User?>? _authSub;

  User? get user => _user;
  bool get loading => _loading;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _user != null || _isGuest;
  String? get uid => _user?.uid ?? (_isGuest ? 'guest_user' : null);
  String? get authError => _authError;
  bool get wasCancelled => _wasCancelled;

  void loginAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

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
    _authError = null;
    _wasCancelled = false;
    try {
      if (!_firebase.isInitialized) {
        await _firebase.initialize();
      }
      final result = await _firebase.signInWithGoogle();
      if (result == null) {
        _wasCancelled = true;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _authError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isGuest = false;
    await _firebase.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
