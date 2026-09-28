import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _guestUidKey = 'guest_device_uid';
  final FirebaseService _firebase = FirebaseService();

  User? _user;
  bool _isGuest = false;
  bool _loading = true;
  String? _authError;
  bool _wasCancelled = false;
  String? _guestUid;
  StreamSubscription<User?>? _authSub;

  User? get user => _user;
  bool get loading => _loading;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _user != null || _isGuest;
  String? get uid => _user?.uid ?? (_isGuest ? _guestUid : null);
  String? get authError => _authError;
  bool get wasCancelled => _wasCancelled;

  Future<void> loginAsGuest() async {
    _isGuest = true;
    await _ensureGuestUid();
    notifyListeners();
  }

  Future<void> _ensureGuestUid() async {
    if (_guestUid != null) return;
    final prefs = await SharedPreferences.getInstance();
    _guestUid = prefs.getString(_guestUidKey);
    if (_guestUid == null) {
      _guestUid = _generateUid();
      await prefs.setString(_guestUidKey, _guestUid!);
    }
  }

  static String _generateUid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return 'guest_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
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
      debugPrint('Auth init error: $e');
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
    _guestUid = null;
    // Remove orphaned guest UID from persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestUidKey);
    await _firebase.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
