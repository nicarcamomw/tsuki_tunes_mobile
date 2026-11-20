import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/first_launch.dart';
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

  /// The account's first start on this phone: its library comes down and
  /// settles before the app shows (the loading screen says what it's
  /// doing), so the first screens don't stutter under that work.
  preparing,
  ready,
}

/// What the first start of an account is doing ([SessionGate.prepStep]).
enum PrepStep {
  /// The library coming down from the account.
  library,

  /// Its lists built and written down, the screens getting ready.
  settling,
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
    if (!_deviceReady) {
      // The first start after install: the loading screen holds while the
      // phone's one-time work passes (FirstLaunch), at most a while.
      prepStep.value = PrepStep.settling;
      unawaited(FirstLaunch.ready.timeout(firstLaunchPatience, onTimeout: () {}).then((_) {
        _deviceReady = true;
        if (prepStep.value == PrepStep.settling) prepStep.value = null;
        _sync();
      }));
    }
    _sync();
  }

  /// False while the first start after install gets the phone ready.
  bool _deviceReady = !FirstLaunch.isFirst;

  /// The longest a first start holds on the loading screen.
  @visibleForTesting
  static Duration firstLaunchPatience = const Duration(seconds: 10);

  final AuthProvider _auth;
  final LibraryRepositoryImpl _library;
  final PlaylistRepositoryImpl _playlists;
  final StorageService _storage;

  String? _connectedUid;
  bool? _onboardingDone;
  bool _onboardingRequested = false;
  SessionStatus _status = SessionStatus.loading;

  /// Whether the signed-in account's first start was prepared on this
  /// phone (null while it's being read).
  bool? _prepared;
  String? _preparedFor;

  /// What the first start is doing now, for the loading screen; null when
  /// nothing is being prepared.
  final ValueNotifier<PrepStep?> prepStep = ValueNotifier(null);

  /// The longest the library is waited for (no network: the app opens
  /// anyway, and the library arrives when it can).
  @visibleForTesting
  static Duration prepPatience = const Duration(seconds: 12);

  /// How long after signing out the account's library is let go: the
  /// app's way out (CircularReveal's portal).
  @visibleForTesting
  static Duration signOutLetGo = const Duration(milliseconds: 800);

  /// A moment for the library's lists to be built and saved before the
  /// first screens draw.
  @visibleForTesting
  static Duration prepSettle = const Duration(milliseconds: 600);

  SessionStatus get status => _status;

  /// Whether the login is letting someone in and plays its way out first:
  /// the router keeps it on screen until it lets go ([holdLogin]).
  bool get loginHeld => _loginHeld;
  bool _loginHeld = false;

  /// Keeps the login on screen while it signs someone in and plays its
  /// exit; letting go moves on to wherever the session is (the app, the
  /// tutorial, or the first start getting ready).
  void holdLogin(bool held) {
    if (held == _loginHeld) return;
    _loginHeld = held;
    notifyListeners();
  }

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
    if (!_deviceReady) return SessionStatus.preparing;
    if (_auth.loading) return SessionStatus.loading;

    if (!_auth.isLoggedIn) {
      if (_connectedUid != null) {
        _connectedUid = null;
        _onboardingRequested = false;
        _onboardingDone = null;
        _preparedFor = null;
        _prepared = null;
        prepStep.value = null;
        // Once the app has left (the login opens over it as it fades): let
        // go of the account's library then, not under the screen still
        // showing it (it emptied before the eyes). Only if no one signed in
        // meanwhile.
        Future<void>.delayed(signOutLetGo, () {
          if (_connectedUid != null) return;
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
    if (uid != null && _preparedFor != uid) {
      _preparedFor = uid;
      _prepared = null;
      // Read now and, when needed, prepared from now: during the tutorial
      // of a new account it's usually done before the tutorial ends.
      unawaited(Future.sync(() => _storage.isFirstStartPrepared(uid)).then((done) {
        if (_preparedFor != uid) return;
        _prepared = done;
        if (!done) unawaited(_prepare(uid));
        _sync();
      }, onError: (Object _) {
        // Storage not answering: never hold the app back for this.
        if (_preparedFor != uid) return;
        _prepared = true;
        _sync();
      }));
    }

    if (!_onboardingRequested) {
      _onboardingRequested = true;
      unawaited(Future.sync(_storage.hasCompletedOnboarding).then((done) {
        _onboardingDone = done;
        _sync();
      }, onError: (Object _) {
        // The phone's storage failed to answer: better the app than the
        // tutorial again, and never the loading screen for good.
        _onboardingDone = true;
        _sync();
      }));
    }
    final done = _onboardingDone;
    if (done == null) return SessionStatus.loading;
    if (!done) return SessionStatus.onboarding;
    final prepared = _prepared;
    if (prepared == null) return uid == null ? SessionStatus.ready : SessionStatus.loading;
    return prepared ? SessionStatus.ready : SessionStatus.preparing;
  }

  /// The account's first start on this phone: waits for its library (not
  /// for a guest's, which is the phone's own) and lets it settle, then
  /// remembers it's done.
  Future<void> _prepare(String uid) async {
    if (!_auth.isGuest) {
      prepStep.value = PrepStep.library;
      await _libraryReady().timeout(prepPatience, onTimeout: () {});
      if (_preparedFor != uid) return;
    }
    prepStep.value = PrepStep.settling;
    await Future<void>.delayed(prepSettle);
    if (_preparedFor != uid) return;
    unawaited(_storage.setFirstStartPrepared(uid).catchError((Object _) {}));
    _prepared = true;
    prepStep.value = null;
    _sync();
  }

  Future<void> _libraryReady() {
    if (_library.listenedTracksLoaded) return Future.value();
    final ready = Completer<void>();
    void check() {
      if (_library.listenedTracksLoaded && !ready.isCompleted) ready.complete();
    }

    _library.addListener(check);
    return ready.future.whenComplete(() => _library.removeListener(check));
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
    _preparedFor = null;
    prepStep.dispose();
    super.dispose();
  }
}
