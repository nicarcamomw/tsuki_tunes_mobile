import 'dart:async';
import 'dart:collection';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/play_day.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/firebase_service.dart';
import '../datasources/play_history_service.dart';
import '../datasources/storage_service.dart';
import '../local/app_database.dart';
import '../local/library_store.dart';
import '../sync/outbox.dart';
import 'album_completion_index.dart';
import 'followed_artists_repository.dart';
import 'listened_tracks_repository.dart';

export 'listened_tracks_repository.dart' show ListenedTrackData;

class TopArtistEntry {
  final String name;
  final int score;
  final int savedCount;
  final int visits;

  TopArtistEntry({
    required this.name,
    required this.score,
    required this.savedCount,
    required this.visits,
  });
}

/// The user's library as the screens see it. Listened tracks, followed
/// artists and album completion live in their own classes; this one wires
/// them to the signed-in user, adds the local favorites, recents and artist
/// visits, and notifies the UI.
class LibraryRepositoryImpl extends ChangeNotifier implements LibraryRepository {
  final StorageService _storage;
  final FirebaseService _firebase;

  late final AlbumCompletionIndex _albums;
  late final ListenedTracksRepository _listened;
  late final FollowedArtistsRepository _followed;

  /// Called when a newly-registered track count reveals a completed album.
  /// Wired to the album_completed product event in app_providers so events
  /// that couldn't fire at listen time (count wasn't known yet) still fire.
  set onAlbumCompleted(void Function(String albumId)? cb) =>
      _albums.onAlbumCompleted = cb;

  // Local data
  List<Track> _favoriteTracks = [];
  List<Track> _recentTracks = [];
  List<Artist> _favoriteArtists = [];
  bool _isLoaded = false;

  bool _syncing = false;
  int _syncCount = 0;

  // Artist visits
  Map<String, int> _artistVisits = {};

  /// [store] and [outbox] hold the listened songs and the writes on their
  /// way to the server; get_it passes the app's database. Without them (a
  /// test) an in-memory database stands in.
  LibraryRepositoryImpl({
    FirebaseService? firebase,
    StorageService? storage,
    LibraryStore? store,
    Outbox? outbox,
    Future<Track?> Function(String trackId)? lookupTrack,
  })  : _firebase = firebase ?? FirebaseService(),
        _storage = storage ?? StorageService() {
    final db = (store == null || outbox == null) ? AppDatabase(NativeDatabase.memory()) : null;
    _albums = AlbumCompletionIndex(
      storage: _storage,
      listenedTracks: () => _listened.tracks,
      listenedLoaded: () => _listened.loaded,
      onChanged: notifyListeners,
    );
    final localStore = store ?? LibraryStore(db!);
    final localOutbox = outbox ?? Outbox(db!);
    _listened = ListenedTracksRepository(
      firebase: _firebase,
      storage: _storage,
      store: localStore,
      outbox: localOutbox,
      lookupTrack: lookupTrack,
      albums: _albums,
      onChanged: notifyListeners,
      tracked: _tracked,
    );
    _followed = FollowedArtistsRepository(
      firebase: _firebase,
      storage: _storage,
      store: localStore,
      outbox: localOutbox,
      onChanged: notifyListeners,
      tracked: _tracked,
    );
    _loadLocalData();
  }

  // Public getters
  List<Track> get favoriteTracks => _favoriteTracks;
  List<Track> get recentTracks => _recentTracks;
  List<Artist> get favoriteArtists => _favoriteArtists;
  bool get isLoaded => _isLoaded;

  List<ListenedTrackData> get listenedTracks => _listened.tracks;
  Set<String> get listenedTrackIds => _listened.ids;
  int get listenedCount => _listened.count;
  int get totalTracksCount => _listened.tracks.length;
  bool get listenedTracksLoaded => _listened.loaded;
  bool get syncing => _syncing;

  /// Last error from a mark/unmark Firestore write, cleared on success.
  /// The UI can watch this to show a snackbar when a save fails.
  String? get lastSyncError => _listened.lastSyncError;

  Map<String, int> get artistVisits => UnmodifiableMapView(_artistVisits);
  List<Artist> get followedArtists => _followed.artists;
  Set<String> get followedArtistIds => _followed.ids;
  @override
  bool isArtistFollowed(String artistId) => _followed.isFollowed(artistId);

  @override
  void notifyListeners() {
    _albums.invalidate();
    _topArtists = null;
    super.notifyListeners();
  }

  /// Runs a Firestore write with [syncing] on.
  Future<void> _tracked(Future<void> Function() write) async {
    _startSync();
    try {
      await write();
    } finally {
      _endSync();
    }
  }

  Future<void> _loadLocalData() async {
    _favoriteTracks = await _storage.getFavoriteTracks();
    _recentTracks = await _storage.getRecentTracks();
    _favoriteArtists = await _storage.getFavoriteArtists();
    _artistVisits = await _storage.getArtistVisits();
    await _albums.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> refreshData() async {
    await _loadLocalData();
    if (_currentUid != null) {
      await connectToFirestore(_currentUid!);
    }
  }

  // --- Album completion ---

  @override
  int getAlbumTracksCount(String albumId) => _albums.trackCount(albumId);
  int listenedCountForAlbum(String albumId) =>
      _albums.listenedCountForAlbum(albumId);
  @override
  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0}) =>
      _albums.isCompleted(albumId, albumTracksCount: albumTracksCount);
  int get uniqueAlbumsCount => _albums.listenedAlbumsCount;

  /// Albums with every song listened.
  int get completedAlbumsCount => _albums.completedAlbumsCount;
  int get uniqueArtistsCount => _listened.uniqueArtistsCount;

  @override
  void registerAlbumTrackCount(String albumId, int count) =>
      _albums.register(albumId, count);

  /// Registers several album track counts with a single rebuild.
  void registerAlbumTrackCounts(Map<String, int> counts) =>
      _albums.registerAll(counts);

  /// Fetches the real track count of albums with listened tracks, so they
  /// can be judged complete. Cheap enough to call from build.
  void ensureAlbumTrackCounts(Iterable<Album> albums,
          Future<Album?> Function(String albumId) fetchAlbum) =>
      _albums.ensureTrackCounts(albums, fetchAlbum);

  // --- Firestore connection ---

  String? _currentUid;
  String? get currentUid => _currentUid;

  @visibleForTesting
  bool bypassAuthForTesting = false;

  @visibleForTesting
  void setUidForTesting(String? uid) {
    _currentUid = uid;
  }

  bool _canSyncToFirestore(String uid) {
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    if (bypassAuthForTesting) return true;
    if (!_firebase.isSignedIn) return false;
    return true;
  }

  /// The signed-in user Firestore writes go to, or null for guests.
  String? get _writeUid {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    return uid != null && _canSyncToFirestore(uid) ? uid : null;
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _listened.isListening) return;
    _currentUid = uid;
    _followed.stopListening();

    final userDoc = _firebase.db.collection('users').doc(uid);
    bool isCurrent() => _currentUid == uid;
    if (!await _listened.connect(uid, userDoc, isCurrent)) return;
    await _followed.connect(uid, userDoc, isCurrent);
  }

  @visibleForTesting
  set followSendHandlerForTesting(Future<void> Function(OutboxEntry entry)? handler) =>
      _followed.sendHandlerForTesting = handler;

  /// Completes once the writes in flight to the server are done.
  @visibleForTesting
  Future<void> pendingWritesSentForTesting() {
    final uid = _writeUid;
    return uid == null ? Future.value() : _listened.idle(uid);
  }

  /// Sends the writes still pending now (the connection came back).
  void retryPendingSync() {
    final uid = _writeUid;
    if (uid != null) unawaited(_listened.retryPending(uid));
  }

  void disconnectFirestore() {
    _currentUid = null;
    _listened.disconnect();
    _albums.clearRequests();
    _followed.disconnect();
    notifyListeners();
  }

  // --- Listened tracks (Firestore) ---

  @override
  bool isTrackListened(String trackId) => _listened.contains(trackId);

  @override
  Future<void> markTrack(Track track) async {
    final uid = _writeUid;
    if (uid == null) return;
    await _listened.mark(uid, track);
  }

  @override
  Future<void> unmarkTrack(String trackId) async {
    final uid = _writeUid;
    if (uid == null) return;
    await _listened.unmark(uid, trackId);
  }

  @override
  Future<void> markAlbumTracks(List<Track> tracks,
      {String? albumId, int? totalTracks}) async {
    final uid = _writeUid;
    if (uid == null) return;

    if (albumId != null && totalTracks != null && totalTracks > 0) {
      registerAlbumTrackCount(albumId, totalTracks);
    } else if (tracks.isNotEmpty && tracks.first.albumId.isNotEmpty) {
      registerAlbumTrackCount(tracks.first.albumId, tracks.length);
    }
    await _listened.markAll(uid, tracks);
  }

  @override
  Future<void> unmarkAlbumTracks(List<String> trackIds) async {
    final uid = _writeUid;
    if (uid == null) return;
    await _listened.unmarkAll(uid, trackIds);
  }

  // --- Testing hooks ---

  @visibleForTesting
  Map<String, int> get albumTrackCounts => _albums.trackCounts;

  @visibleForTesting
  void pruneAlbumTrackCounts({bool forceSave = false}) =>
      _albums.prune(forceSave: forceSave);

  @visibleForTesting
  void setListenedTracksLoadedForTesting(bool loaded) {
    _listened.setLoadedForTesting(loaded);
  }

  @visibleForTesting
  Future<void> setListenedTracksForTesting(List<ListenedTrackData> tracks) {
    final saved = _listened.setTracksForTesting(tracks, uid: _currentUid);
    _albums.invalidate();
    _topArtists = null;
    return saved;
  }

  /// Applies an unmark made on another device. A track re-marked after the
  /// deletion (newer listenedAt) is kept. Returns whether anything changed.
  @visibleForTesting
  bool applyRemoteDeletion(String trackId, DateTime deletedAt) =>
      _listened.applyRemoteDeletion(trackId, deletedAt);

  @visibleForTesting
  Future<void> Function(List<ListenedTrackData> chunk, String uid)?
      get markAlbumChunkHandlerForTesting =>
          _listened.markChunkHandlerForTesting;
  @visibleForTesting
  set markAlbumChunkHandlerForTesting(
          Future<void> Function(List<ListenedTrackData> chunk, String uid)?
              handler) =>
      _listened.markChunkHandlerForTesting = handler;

  @visibleForTesting
  Future<void> Function(List<String> chunkIds, String uid)?
      get unmarkAlbumChunkHandlerForTesting =>
          _listened.unmarkChunkHandlerForTesting;
  @visibleForTesting
  set unmarkAlbumChunkHandlerForTesting(
          Future<void> Function(List<String> chunkIds, String uid)?
              handler) =>
      _listened.unmarkChunkHandlerForTesting = handler;

  // --- Play log (every play, per day) ---

  PlayHistoryService? _playHistory;
  PlayHistoryService get _history =>
      _playHistory ??= PlayHistoryService(_firebase.db);

  /// Counts one real play (the player calls this once per play, past the
  /// listen threshold). Fire-and-forget: offline writes sync later.
  @override
  Future<void> recordPlay(Track track) async {
    final uid = _writeUid;
    if (uid == null || track.id.isEmpty) return;
    try {
      await _history.recordPlay(uid, track);
    } catch (e) {
      debugPrint('[LibraryRepositoryImpl] recordPlay failed: $e');
    }
  }

  Future<List<PlayDay>> loadPlayDays(DateTime from, DateTime to) async {
    final uid = _writeUid;
    if (uid == null) return const [];
    try {
      return await _history.loadRange(uid, from, to);
    } catch (e) {
      debugPrint('[LibraryRepositoryImpl] loadPlayDays failed: $e');
      return const [];
    }
  }

  Future<DateTime?> firstRecordedPlayDay() async {
    final uid = _writeUid;
    if (uid == null) return null;
    try {
      return await _history.firstRecordedDay(uid);
    } catch (_) {
      return null;
    }
  }

  // The syncing flag only tells when it turns on or off, and without
  // dropping the derived caches (album counts, top artists): nothing in the
  // library changed. Writes go out one after another in the background
  // while songs play, so this matters.
  void _startSync() {
    _syncCount++;
    if (_syncing) return;
    _syncing = true;
    super.notifyListeners();
  }

  void _endSync() {
    _syncCount--;
    if (_syncCount > 0) return;
    _syncCount = 0;
    if (!_syncing) return;
    _syncing = false;
    super.notifyListeners();
  }

  // --- Top Artists calculation (like web) ---

  // Full ranking, rebuilt after a mutation (notifyListeners clears it): the
  // home screen asks for it on every library change.
  List<TopArtistEntry>? _topArtists;

  List<TopArtistEntry> getTopArtists({int limit = 5}) {
    final all = _topArtists ??= _rankArtists();
    return all.take(limit).toList();
  }

  List<TopArtistEntry> _rankArtists() {
    final Map<String, int> savedCounts = {};
    // Each artist of each song, so a collaboration counts for each of its
    // artists instead of as one more artist.
    for (final t in _listened.tracks) {
      for (final name in t.artists) {
        savedCounts[name] = (savedCounts[name] ?? 0) + 1;
      }
    }

    final allArtists = <String>{...savedCounts.keys, ..._artistVisits.keys};
    final entries = <TopArtistEntry>[];

    for (final name in allArtists) {
      final saved = savedCounts[name] ?? 0;
      final visits = _artistVisits[name] ?? 0;
      final score = (saved * 2) + visits;
      entries.add(TopArtistEntry(
        name: name,
        score: score,
        savedCount: saved,
        visits: visits,
      ));
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }

  // --- Artist visits ---

  Future<void> trackArtistVisit(String artistName) async {
    _artistVisits[artistName] = (_artistVisits[artistName] ?? 0) + 1;
    notifyListeners();
    await _storage.saveArtistVisits(_artistVisits);
  }

  // --- Favorites (local, same as before) ---

  @override
  bool isFavoriteTrack(String trackId) {
    return _favoriteTracks.any((t) => t.id == trackId);
  }

  @override
  Future<void> toggleFavoriteTrack(Track track) async {
    final index = _favoriteTracks.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _favoriteTracks.removeAt(index);
    } else {
      _favoriteTracks.insert(0, track);
    }
    notifyListeners();
    await _storage.saveFavoriteTracks(_favoriteTracks);
  }

  @override
  Future<void> addRecentTrack(Track track) async {
    _recentTracks.removeWhere((t) => t.id == track.id);
    _recentTracks.insert(0, track);
    if (_recentTracks.length > 50) {
      _recentTracks = _recentTracks.sublist(0, 50);
    }
    notifyListeners();
    await _storage.saveRecentTracks(_recentTracks);
  }

  @override
  bool isFavoriteArtist(String artistId) {
    return _favoriteArtists.any((a) => a.id == artistId);
  }

  @override
  Future<void> toggleFavoriteArtist(Artist artist) async {
    final index = _favoriteArtists.indexWhere((a) => a.id == artist.id);
    if (index >= 0) {
      _favoriteArtists.removeAt(index);
    } else {
      _favoriteArtists.insert(0, artist);
    }
    notifyListeners();
    await _storage.saveFavoriteArtists(_favoriteArtists);
  }

  // --- Followed artists (Firestore-synced) ---

  @override
  Future<void> followArtist(Artist artist) async {
    final uid = _writeUid;
    if (uid == null) return;
    await _followed.follow(uid, artist);
  }

  @override
  Future<void> unfollowArtist(String artistId) async {
    final uid = _writeUid;
    if (uid == null) return;
    await _followed.unfollow(uid, artistId);
  }

  @override
  void dispose() {
    _listened.dispose();
    _followed.dispose();
    super.dispose();
  }
}
