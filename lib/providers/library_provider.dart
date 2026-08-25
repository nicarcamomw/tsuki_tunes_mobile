import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class ListenedTrackData {
  final String trackId;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumId;
  final String coverUrl;
  final String previewUrl;
  final int duration;
  final DateTime? listenedAt;

  ListenedTrackData({
    required this.trackId,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumId,
    required this.coverUrl,
    this.previewUrl = '',
    required this.duration,
    this.listenedAt,
  });

  factory ListenedTrackData.fromFirestore(Map<String, dynamic> data) {
    DateTime? listened;
    if (data['listenedAt'] is Timestamp) {
      listened = (data['listenedAt'] as Timestamp).toDate();
    }
    return ListenedTrackData(
      trackId: data['trackId'] ?? '',
      title: data['title'] ?? '',
      artistName: data['artistName'] ?? '',
      albumTitle: data['albumTitle'] ?? '',
      albumId: data['albumId'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      previewUrl: data['previewUrl'] ?? '',
      duration: data['duration'] ?? 0,
      listenedAt: listened,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
        'listenedAt': FieldValue.serverTimestamp(),
      };
}

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

class LibraryProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final FirebaseService _firebase = FirebaseService();

  // Local data
  List<Track> _favoriteTracks = [];
  List<Track> _recentTracks = [];
  List<Artist> _favoriteArtists = [];
  bool _isLoaded = false;

  // Firestore listened tracks
  List<ListenedTrackData> _listenedTracks = [];
  Set<String> _listenedTrackIds = {};
  int _totalTracksCount = 0;
  bool _syncing = false;
  int _syncCount = 0;

  // Artist visits
  Map<String, int> _artistVisits = {};

  // Firestore subscriptions
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _statsSubscription;

  // Public getters
  List<Track> get favoriteTracks => _favoriteTracks;
  List<Track> get recentTracks => _recentTracks;
  List<Artist> get favoriteArtists => _favoriteArtists;
  bool get isLoaded => _isLoaded;

  List<ListenedTrackData> get listenedTracks => _listenedTracks;
  Set<String> get listenedTrackIds => _listenedTrackIds;
  int get totalTracksCount => _totalTracksCount;
  bool get syncing => _syncing;
  Map<String, int> get artistVisits => _artistVisits;

  int get uniqueArtistsCount {
    final artists = <String>{};
    for (final t in _listenedTracks) {
      if (t.artistName.isNotEmpty) artists.add(t.artistName);
    }
    return artists.length;
  }

  int get uniqueAlbumsCount {
    final albums = <String>{};
    for (final t in _listenedTracks) {
      if (t.albumId.isNotEmpty) albums.add(t.albumId);
    }
    return albums.length;
  }

  LibraryProvider() {
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    _favoriteTracks = await _storage.getFavoriteTracks();
    _recentTracks = await _storage.getRecentTracks();
    _favoriteArtists = await _storage.getFavoriteArtists();
    _artistVisits = await _storage.getArtistVisits();
    _isLoaded = true;
    notifyListeners();
  }

  void connectToFirestore(String uid) {
    _tracksSubscription?.cancel();
    _statsSubscription?.cancel();

    final db = _firebase.db;
    final userDoc = db.collection('users').doc(uid);

    _tracksSubscription = userDoc
        .collection('listenedTracks')
        .snapshots()
        .listen((snapshot) {
      _listenedTracks = snapshot.docs
          .map((doc) => ListenedTrackData.fromFirestore(doc.data()))
          .toList();
      _listenedTrackIds =
          _listenedTracks.map((t) => t.trackId).toSet();
      notifyListeners();
    });

    _statsSubscription = userDoc.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final stats = data?['stats'];
        if (stats is Map) {
          _totalTracksCount = stats['totalTracks'] ?? 0;
        }
      }
      notifyListeners();
    });
  }

  void disconnectFirestore() {
    _tracksSubscription?.cancel();
    _statsSubscription?.cancel();
    _listenedTracks = [];
    _listenedTrackIds = {};
    _totalTracksCount = 0;
    notifyListeners();
  }

  // --- Listened tracks (Firestore) ---

  bool isTrackListened(String trackId) => _listenedTrackIds.contains(trackId);

  Future<void> markTrack(Track track) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    if (_listenedTrackIds.contains(track.id)) return;

    // Optimistic update
    final data = ListenedTrackData(
      trackId: track.id,
      title: track.title,
      artistName: track.fullArtistName,
      albumTitle: track.albumTitle,
      albumId: track.albumId,
      coverUrl: track.coverUrl,
      duration: track.durationSeconds,
      previewUrl: track.previewUrl,
      listenedAt: DateTime.now(),
    );
    _listenedTracks.add(data);
    _listenedTrackIds.add(track.id);
    notifyListeners();

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      final batch = db.batch();
      batch.set(
        userDoc.collection('listenedTracks').doc(track.id),
        data.toFirestore(),
        SetOptions(merge: true),
      );
      batch.update(userDoc, {
        'stats.totalTracks': FieldValue.increment(1),
      });
      await batch.commit();
    } catch (e) {
      // Rollback
      _listenedTracks.removeWhere((t) => t.trackId == track.id);
      _listenedTrackIds.remove(track.id);
      notifyListeners();
      debugPrint('markTrack error: $e');
    } finally {
      _endSync();
    }
  }

  Future<void> unmarkTrack(String trackId) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;
    if (!_listenedTrackIds.contains(trackId)) return;

    // Optimistic update
    final removed =
        _listenedTracks.where((t) => t.trackId == trackId).toList();
    _listenedTracks.removeWhere((t) => t.trackId == trackId);
    _listenedTrackIds.remove(trackId);
    notifyListeners();

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      final batch = db.batch();
      batch.delete(userDoc.collection('listenedTracks').doc(trackId));
      batch.update(userDoc, {
        'stats.totalTracks': FieldValue.increment(-1),
      });
      await batch.commit();
    } catch (e) {
      // Rollback
      _listenedTracks.addAll(removed);
      _listenedTrackIds.add(trackId);
      notifyListeners();
      debugPrint('unmarkTrack error: $e');
    } finally {
      _endSync();
    }
  }

  Future<void> markAlbumTracks(List<Track> tracks) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final toMark =
        tracks.where((t) => !_listenedTrackIds.contains(t.id)).toList();
    if (toMark.isEmpty) return;

    // Optimistic update
    final newData = toMark
        .map((t) => ListenedTrackData(
              trackId: t.id,
              title: t.title,
              artistName: t.fullArtistName,
              albumTitle: t.albumTitle,
              albumId: t.albumId,
              coverUrl: t.coverUrl,
              previewUrl: t.previewUrl,
              duration: t.durationSeconds,
              listenedAt: DateTime.now(),
            ))
        .toList();
    _listenedTracks.addAll(newData);
    _listenedTrackIds.addAll(toMark.map((t) => t.id));
    notifyListeners();

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      final batch = db.batch();

      for (final data in newData) {
        batch.set(
          userDoc.collection('listenedTracks').doc(data.trackId),
          data.toFirestore(),
          SetOptions(merge: true),
        );
      }
      batch.update(userDoc, {
        'stats.totalTracks': FieldValue.increment(toMark.length),
      });

      await batch.commit();
    } catch (e) {
      // Rollback
      final ids = toMark.map((t) => t.id).toSet();
      _listenedTracks.removeWhere((t) => ids.contains(t.trackId));
      _listenedTrackIds.removeAll(ids);
      notifyListeners();
      debugPrint('markAlbumTracks error: $e');
    } finally {
      _endSync();
    }
  }

  Future<void> unmarkAlbumTracks(List<String> trackIds) async {
    final uid = _firebase.currentUser?.uid;
    if (uid == null) return;

    final toUnmark =
        trackIds.where((id) => _listenedTrackIds.contains(id)).toList();
    if (toUnmark.isEmpty) return;

    // Optimistic update
    final removed = _listenedTracks
        .where((t) => toUnmark.contains(t.trackId))
        .toList();
    _listenedTracks.removeWhere((t) => toUnmark.contains(t.trackId));
    _listenedTrackIds.removeAll(toUnmark);
    notifyListeners();

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      final batch = db.batch();

      for (final id in toUnmark) {
        batch.delete(userDoc.collection('listenedTracks').doc(id));
      }
      batch.update(userDoc, {
        'stats.totalTracks': FieldValue.increment(-toUnmark.length),
      });

      await batch.commit();
    } catch (e) {
      // Rollback
      _listenedTracks.addAll(removed);
      _listenedTrackIds.addAll(toUnmark);
      notifyListeners();
      debugPrint('unmarkAlbumTracks error: $e');
    } finally {
      _endSync();
    }
  }

  void _startSync() {
    _syncCount++;
    _syncing = true;
    notifyListeners();
  }

  void _endSync() {
    _syncCount--;
    if (_syncCount <= 0) {
      _syncCount = 0;
      _syncing = false;
      notifyListeners();
    }
  }

  // --- Top Artists calculation (like web) ---

  List<TopArtistEntry> getTopArtists({int limit = 5}) {
    final Map<String, int> savedCounts = {};
    for (final t in _listenedTracks) {
      final name = t.artistName;
      if (name.isNotEmpty) {
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
    return entries.take(limit).toList();
  }

  // --- Artist visits ---

  Future<void> trackArtistVisit(String artistName) async {
    _artistVisits[artistName] = (_artistVisits[artistName] ?? 0) + 1;
    notifyListeners();
    await _storage.saveArtistVisits(_artistVisits);
  }

  // --- Favorites (local, same as before) ---

  bool isFavoriteTrack(String trackId) {
    return _favoriteTracks.any((t) => t.id == trackId);
  }

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

  Future<void> addRecentTrack(Track track) async {
    _recentTracks.removeWhere((t) => t.id == track.id);
    _recentTracks.insert(0, track);
    if (_recentTracks.length > 50) {
      _recentTracks = _recentTracks.sublist(0, 50);
    }
    notifyListeners();
    await _storage.saveRecentTracks(_recentTracks);
  }

  bool isFavoriteArtist(String artistId) {
    return _favoriteArtists.any((a) => a.id == artistId);
  }

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

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }
}
