import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/account_deletion_service.dart';
import '../../data/datasources/firebase_service.dart';
import '../../data/datasources/storage_service.dart';
import '../../di/injection.dart';
import '../../core/logger.dart';


final _log = Log.named('Auth');

enum AccountDeletionResult {
  deleted,
  /// The Google sign-in asked first was cancelled: nothing was touched.
  cancelled,
  /// No connection to Firestore: nothing was touched.
  offline,
  /// Stopped partway; the person was signed out and can sign in and try
  /// again (what's already deleted stays deleted).
  failed,
}

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
      _log.severe('Guest restore error: $e');
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
      _log.severe('Auth init error: $e');
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
      _log.severe('Google sign-in error: $e');
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

  /// Deletes the signed-in account and everything it keeps: its data in
  /// Firestore, what this phone keeps for it, and the sign-in account
  /// itself. Google sign-in is asked again first (Firebase requires a
  /// recent one). [beforeDelete] runs once that's done and Firestore is
  /// reachable, right before anything is deleted: stop playback and the
  /// syncing that would write the data back.
  Future<AccountDeletionResult> deleteAccount({
    Future<void> Function()? beforeDelete,
  }) async {
    final user = _user;
    if (user == null || _isGuest) return AccountDeletionResult.failed;
    final uid = user.uid;
    try {
      if (!await _firebase.reauthenticateWithGoogle()) {
        return AccountDeletionResult.cancelled;
      }
    } catch (e) {
      _log.severe('Re-authentication before deleting the account failed: $e');
      return AccountDeletionResult.failed;
    }
    final firestore = _firebase.db;
    try {
      await firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
    } catch (e) {
      _log.warning('Firestore unreachable, account not deleted: $e');
      return AccountDeletionResult.offline;
    }

    try {
      await beforeDelete?.call();
    } catch (e) {
      _log.warning('Preparing the account deletion failed (non-fatal): $e');
    }
    try {
      await AccountDeletionService(firestore).deleteUserData(uid);
      await getIt<StorageService>().clearAccountData(uid);
      await _firebase.deleteCurrentUser();
    } catch (e) {
      _log.severe('Account deletion stopped partway: $e');
      await logout();
      return AccountDeletionResult.failed;
    }
    _user = null;
    notifyListeners();
    return AccountDeletionResult.deleted;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
