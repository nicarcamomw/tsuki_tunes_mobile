import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/firebase_service.dart';
import '../../data/datasources/storage_service.dart';
import '../../di/injection.dart';

class AuthProvider extends ChangeNotifier {
  static const _guestUidKey = 'guest_device_uid';
  static const _guestModeKey = 'guest_mode_active';
  static const _maxLoginAttempts = 5;
  static const _loginCooldownBase = Duration(seconds: 5);
  final FirebaseService _firebase = FirebaseService();

  User? _user;
  bool _isGuest = false;
  bool _loading = true;
  String? _authError;
  bool _wasCancelled = false;
  String? _guestUid;
  StreamSubscription<User?>? _authSub;
  String? _guestUidToMigrate;
  int _loginAttempts = 0;
  DateTime? _lastLoginAttemptTime;

  User? get user => _user;
  bool get loading => _loading;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _user != null || _isGuest;
  String? get uid => _user?.uid ?? (_isGuest ? _guestUid : null);
  String? get authError => _authError;
  bool get wasCancelled => _wasCancelled;
  bool get isAuthenticated => _user != null && !_isGuest;

  bool get isLoginThrottled {
    if (_loginAttempts < _maxLoginAttempts) return false;
    if (_lastLoginAttemptTime == null) return false;
    final multiplier = (_loginAttempts - _maxLoginAttempts).clamp(0, 4);
    final cooldown = _loginCooldownBase * (1 << multiplier);
    return DateTime.now().difference(_lastLoginAttemptTime!) < cooldown;
  }

  Future<void> loginAsGuest() async {
    if (_isGuest) return;
    _isGuest = true;
    await _ensureGuestUid();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    notifyListeners();
  }

  /// Guest uid whose local data (playlists) should be moved into the account
  /// that just signed in. Returns it once and forgets it.
  String? takeGuestUidToMigrate() {
    final uid = _guestUidToMigrate;
    _guestUidToMigrate = null;
    return uid;
  }

  Future<void> _leaveGuestMode() async {
    if (!_isGuest) return;
    _guestUidToMigrate = _guestUid;
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
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
    // Restore guest mode so guests don't land on the login screen each launch.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_guestModeKey) == true) {
        _guestUid = prefs.getString(_guestUidKey);
        _isGuest = _guestUid != null;
      }
    } catch (e) {
      debugPrint('Guest restore error: $e');
    }
    try {
      await _firebase.initialize();
      _authSub = _firebase.auth.authStateChanges().listen((user) async {
        _user = user;
        // A signed-in account always wins over a leftover guest session.
        if (user != null && _isGuest) await _leaveGuestMode();
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
    if (isLoginThrottled) {
      _authError = 'login_throttled';
      notifyListeners();
      return false;
    }
    _authError = null;
    _wasCancelled = false;
    _lastLoginAttemptTime = DateTime.now();
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
      _loginAttempts = 0;
      await _leaveGuestMode();
      notifyListeners();
      return true;
    } catch (e) {
      _loginAttempts++;
      debugPrint('Google sign-in error: $e');
      _authError = 'login_failed';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final leftGuestUid = _isGuest ? _guestUid : null;
    _isGuest = false;
    _guestUid = null;
    // Remove orphaned guest UID from persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestUidKey);
    await prefs.remove(_guestModeKey);
    // The guest's playlists can't be reached once its uid is gone.
    if (leftGuestUid != null) await getIt<StorageService>().clearCachedPlaylists(leftGuestUid);
    await _firebase.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
