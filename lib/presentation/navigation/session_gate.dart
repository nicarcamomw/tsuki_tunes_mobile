import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/datasources/storage_service.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../state/auth_provider.dart';

/// Where the session is, which decides the app's first screen.
enum SessionStatus {
  /// Auth (or the onboarding flag) is still loading.
  loading,
  signedOut,

  /// Signed in, but the tutorial hasn't been seen yet.
  onboarding,
  ready,
}

/// Follows sign-in and sign-out: connects the library and playlists to the
/// account (or to local storage for guests), disconnects them on sign-out,
/// and knows whether the tutorial was seen. The router redirects on every
/// change (refreshListenable), so no screen navigates after a login.
class SessionGate extends ChangeNotifier {
  SessionGate({
    required AuthProvider auth,
    required LibraryRepositoryImpl library,
    required PlaylistRepositoryImpl playlists,
    required StorageService storage,
  })  : _auth = auth,
        _library = library,
        _playlists = playlists,
        _storage = storage {
    _auth.addListener(_sync);
    _sync();
  }

  final AuthProvider _auth;
  final LibraryRepositoryImpl _library;
  final PlaylistRepositoryImpl _playlists;
  final StorageService _storage;

  String? _connectedUid;
  bool? _onboardingDone;
  bool _onboardingRequested = false;
  SessionStatus _status = SessionStatus.loading;

  SessionStatus get status => _status;

  /// Guests may still open the login screen to sign in with Google.
  bool get isGuest => _auth.isGuest;

  void _sync() {
    final next = _compute();
    if (next != _status) {
      _status = next;
      notifyListeners();
    }
  }

  SessionStatus _compute() {
    if (_auth.loading) return SessionStatus.loading;

    if (!_auth.isLoggedIn) {
      if (_connectedUid != null) {
        _connectedUid = null;
        _onboardingRequested = false;
        _onboardingDone = null;
        // Outside the current build or notification, like the old gate's
        // post-frame callback.
        scheduleMicrotask(() {
          _library.disconnectFirestore();
          _playlists.disconnectFirestore();
        });
      }
      return SessionStatus.signedOut;
    }

    final uid = _auth.uid;
    if (uid != null && _connectedUid != uid) {
      _connectedUid = uid;
      scheduleMicrotask(() => _connect(uid));
    }

    if (!_onboardingRequested) {
      _onboardingRequested = true;
      unawaited(_storage.hasCompletedOnboarding().then((done) {
        _onboardingDone = done;
        _sync();
      }));
    }
    final done = _onboardingDone;
    if (done == null) return SessionStatus.loading;
    return done ? SessionStatus.ready : SessionStatus.onboarding;
  }

  void _connect(String uid) {
    if (_auth.isGuest) {
      unawaited(_playlists.initLocalOnly(uid));
      return;
    }
    unawaited(_library.connectToFirestore(uid));
    final guestUid = _auth.takeGuestUidToMigrate();
    unawaited(_playlists.connectToFirestore(uid).then((_) {
      if (guestUid != null) _playlists.importGuestPlaylists(guestUid);
    }));
  }

  /// Remembers on this phone that the tutorial was seen.
  Future<void> saveOnboardingDone() => _storage.setCompletedOnboarding(true);

  /// The first-run tutorial ended (after [saveOnboardingDone]).
  void onboardingCompleted() {
    _onboardingDone = true;
    _sync();
  }

  @override
  void dispose() {
    _auth.removeListener(_sync);
    super.dispose();
  }
}
