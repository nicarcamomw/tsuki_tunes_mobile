import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/artist.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/profile/build_my_profile.dart';

/// Keeps the signed-in user's public profile up to date: when the library,
/// the mask or the account change it waits a moment and publishes, only if
/// something others would see changed, and at most every [minInterval] (the
/// free quota). Switching between public and private goes out at once.
/// Guests have no profile.
class ProfileController extends ChangeNotifier {
  ProfileController({
    required ProfileRepository repository,
    required Listenable changes,
    required String? Function() uid,
    required String Function() displayName,
    required String? Function() photoUrl,
    required String? Function() maskId,
    required bool Function() libraryLoaded,
    required Iterable<String> Function() listenedArtistNames,
    required int Function() albumsCompleted,
    required Iterable<Artist> Function() knownArtists,
    this.debounce = const Duration(seconds: 20),
    this.minInterval = const Duration(minutes: 10),
    DateTime Function()? clock,
  })  : _repo = repository,
        _changes = changes,
        _uid = uid,
        _displayName = displayName,
        _photoUrl = photoUrl,
        _maskId = maskId,
        _libraryLoaded = libraryLoaded,
        _listenedArtistNames = listenedArtistNames,
        _albumsCompleted = albumsCompleted,
        _knownArtists = knownArtists,
        _now = clock ?? DateTime.now {
    _changes.addListener(_onChange);
    _onChange();
  }

  final ProfileRepository _repo;
  final Listenable _changes;
  final String? Function() _uid;
  final String Function() _displayName;
  final String? Function() _photoUrl;
  final String? Function() _maskId;
  final bool Function() _libraryLoaded;
  final Iterable<String> Function() _listenedArtistNames;
  final int Function() _albumsCompleted;
  final Iterable<Artist> Function() _knownArtists;
  final DateTime Function() _now;

  /// Quiet time after a change before publishing, and the least time
  /// between two publishes.
  final Duration debounce;
  final Duration minInterval;

  /// The rules take one write every 10 seconds; a little over.
  static const _serverGap = Duration(seconds: 11);

  String? _account;
  bool _ready = false;
  bool _isPublic = false;
  PublicProfile? _published;
  DateTime? _publishedAt;
  Timer? _timer;
  Future<void>? _publishing;

  /// Whether the signed-in user has a profile (not a guest) and it loaded.
  bool get available => _account != null && _ready;
  bool get isPublic => _isPublic;
  String? get uid => _account;

  /// The link others open the profile with.
  String? get shareLink => _account == null ? null : 'tsukitunes://user/$_account';

  /// The profile as it would be published now.
  PublicProfile? get current {
    final uid = _account;
    if (uid == null) return null;
    return const BuildMyProfile()(
      uid: uid,
      displayName: _displayName(),
      photoUrl: _photoUrl(),
      maskId: _maskId(),
      isPublic: _isPublic,
      listenedArtistNames: _listenedArtistNames(),
      albumsCompleted: _albumsCompleted(),
      knownArtists: _knownArtists(),
    );
  }

  void _onChange() {
    final uid = _uid();
    if (uid != _account) {
      _account = uid;
      _ready = false;
      _published = null;
      _publishedAt = null;
      _isPublic = false;
      _timer?.cancel();
      notifyListeners();
      if (uid != null) unawaited(_load(uid));
      return;
    }
    if (_ready) _schedule(debounce);
  }

  /// What the account already has published: its visibility and the
  /// content to compare with.
  Future<void> _load(String uid) async {
    PublicProfile? remote;
    try {
      remote = await _repo.getProfile(uid);
    } catch (e) {
      debugPrint('[Profile] reading the published profile failed: $e');
    }
    if (_account != uid) return;
    _published = remote;
    _publishedAt = remote?.updatedAt;
    _isPublic = remote?.isPublic ?? false;
    _ready = true;
    notifyListeners();
    _schedule(debounce);
  }

  /// Makes the profile public or private, published right away.
  Future<void> setPublic(bool value) async {
    if (!available || value == _isPublic) return;
    _isPublic = value;
    notifyListeners();
    _timer?.cancel();
    await _publish(force: true);
  }

  void _schedule(Duration wait, {bool force = false}) {
    _timer?.cancel();
    _timer = Timer(wait, () => unawaited(_publish(force: force)));
  }

  /// Publishes when something changed; [force] skips [minInterval] (a
  /// visibility switch) but not the server's 10 seconds.
  Future<void> _publish({bool force = false}) async {
    final running = _publishing;
    if (running != null) {
      await running;
      if (!force) return;
    }
    final uid = _account;
    // Stats only once the library has loaded, never the zeros of a cold start.
    if (uid == null || !_ready || !_libraryLoaded()) return;
    final profile = current!;
    final last = _published;
    if (last != null && last.sameContentAs(profile)) return;

    final since = _publishedAt == null ? null : _now().difference(_publishedAt!);
    if (since != null) {
      final gap = force ? _serverGap : minInterval;
      if (since < gap) {
        // A forced publish stays forced when it has to wait.
        _schedule(gap - since, force: force);
        return;
      }
    }
    final attempt = _repo.saveMyProfile(profile).then((_) {
      if (_account != uid) return;
      _published = profile;
      _publishedAt = _now();
    }).catchError((Object e) {
      debugPrint('[Profile] publishing failed, next change retries: $e');
    });
    _publishing = attempt;
    // The time counts from the send: offline, Firestore holds the write
    // until it reaches the server.
    _publishedAt = _now();
    await attempt;
    _publishing = null;
  }

  @override
  void dispose() {
    _changes.removeListener(_onChange);
    _timer?.cancel();
    super.dispose();
  }
}
