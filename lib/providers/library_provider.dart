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

  factory ListenedTrackData.fromFirestore(Map<String, dynamic> data,
      {String? docId}) {
    DateTime? listened;
    final rawListened = data['listenedAt'];
    if (rawListened is Timestamp) {
      listened = rawListened.toDate();
    } else if (rawListened is Map) {
      final sec = rawListened['seconds'] ?? rawListened['_seconds'];
      if (sec is num) {
        listened = DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
      }
    } else if (rawListened is String) {
      listened = DateTime.tryParse(rawListened);
    }

    final tid = data['trackId']?.toString() ?? docId ?? '';
    final aid = data['albumId']?.toString() ?? '';
    final dur =
        data['duration'] is num ? (data['duration'] as num).toInt() : 0;

    return ListenedTrackData(
      trackId: tid,
      title: data['title']?.toString() ?? '',
      artistName: data['artistName']?.toString() ?? '',
      albumTitle: data['albumTitle']?.toString() ?? '',
      albumId: aid,
      coverUrl: data['coverUrl']?.toString() ?? '',
      previewUrl: data['previewUrl']?.toString() ?? '',
      duration: dur,
      listenedAt: listened,
    );
  }

  factory ListenedTrackData.fromJson(Map<String, dynamic> json) {
    DateTime? listened;
    if (json['listenedAt'] != null) {
      listened = DateTime.tryParse(json['listenedAt'].toString());
    }
    return ListenedTrackData(
      trackId: json['trackId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artistName: json['artistName']?.toString() ?? '',
      albumTitle: json['albumTitle']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString() ?? '',
      duration:
          json['duration'] is num ? (json['duration'] as num).toInt() : 0,
      listenedAt: listened,
    );
  }

  Map<String, dynamic> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'previewUrl': previewUrl,
        'duration': duration,
        'listenedAt': listenedAt?.toIso8601String(),
      };

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

  // Album track counts cache (albumId -> totalTracks)
  Map<String, int> _albumTrackCounts = {};

  // Firestore subscriptions
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _statsSubscription;

  // Public getters
  List<Track> get favoriteTracks => _favoriteTracks;
  List<Track> get recentTracks => _recentTracks;
  List<Artist> get favoriteArtists => _favoriteArtists;
  bool get isLoaded => _isLoaded;

  List<ListenedTrackData> get listenedTracks => List.unmodifiable(_listenedTracks);
  Set<String> get listenedTrackIds => Set.unmodifiable(_listenedTrackIds);
  int get totalTracksCount => _totalTracksCount;
  bool get syncing => _syncing;
  Map<String, int> get artistVisits => Map.unmodifiable(_artistVisits);

  int getAlbumTracksCount(String albumId) => _albumTrackCounts[albumId] ?? 0;

  void registerAlbumTrackCount(String albumId, int count) {
    if (albumId.isEmpty || count <= 0) return;
    if (_albumTrackCounts[albumId] == count) return;
    _albumTrackCounts[albumId] = count;
    _storage.saveAlbumTrackCounts(_albumTrackCounts);
    notifyListeners();
  }

  bool isAlbumCompleted(String albumId, {int albumTracksCount = 0}) {
    if (albumId.isEmpty) return false;
    final listenedCount =
        _listenedTracks.where((t) => t.albumId == albumId).length;
    if (listenedCount == 0) return false;

    final total = albumTracksCount > 0
        ? albumTracksCount
        : (_albumTrackCounts[albumId] ?? 0);

    if (total <= 0) return false;
    return listenedCount >= total;
  }

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
    _albumTrackCounts = await _storage.getAlbumTrackCounts();
    _isLoaded = true;
    notifyListeners();
  }

  String? _currentUid;
  String? get currentUid => _currentUid;

  bool _canSyncToFirestore(String uid) {
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    if (_firebase.currentUser == null) return false;
    return true;
  }

  Future<void> connectToFirestore(String uid) async {
    if (!_canSyncToFirestore(uid)) return;
    if (_currentUid == uid && _tracksSubscription != null) return;
    _currentUid = uid;

    _tracksSubscription?.cancel();
    _statsSubscription?.cancel();

    final db = _firebase.db;
    final userDoc = db.collection('users').doc(uid);
    final tracksCol = userDoc.collection('listenedTracks');

    // 1. Instant local cache restore (0ms cold start — tracks never disappear)
    try {
      final cached = await _storage.getCachedListenedTracks(uid);
      if (cached.isNotEmpty && _currentUid == uid) {
        _listenedTracks =
            cached.map((e) => ListenedTrackData.fromJson(e)).toList();
        _listenedTrackIds = _listenedTracks.map((t) => t.trackId).toSet();
        _totalTracksCount = _listenedTracks.length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] Error restoring cached tracks: $e');
    }

    // 2. One-time full fetch — same read cost as a listener's first snapshot,
    //    but avoids re-reading the entire collection on every reconnection.
    DateTime? deltaBoundary;
    try {
      final snapshot =
          await tracksCol.orderBy('listenedAt', descending: true).get();
      if (_currentUid != uid) return;

      _listenedTracks = snapshot.docs
          .map((doc) =>
              ListenedTrackData.fromFirestore(doc.data(), docId: doc.id))
          .toList();
      _listenedTrackIds = _listenedTracks.map((t) => t.trackId).toSet();
      _totalTracksCount = _listenedTracks.length;
      notifyListeners();

      _storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      );

      for (final t in _listenedTracks) {
        if (t.listenedAt != null &&
            (deltaBoundary == null || t.listenedAt!.isAfter(deltaBoundary))) {
          deltaBoundary = t.listenedAt;
        }
      }
      _pruneAlbumTrackCounts();
    } catch (e) {
      debugPrint('[LibraryProvider] Initial Firestore fetch error: $e');
    }

    // 3. Delta listener — only docs newer than the latest known timestamp.
    //    Reconnections after 30+ min re-read only THIS query's result set
    //    (typically 0-few docs) instead of the entire 2000+ collection.
    final deltaQuery = deltaBoundary != null
        ? tracksCol
            .where('listenedAt',
                isGreaterThan: Timestamp.fromDate(deltaBoundary))
            .orderBy('listenedAt', descending: true)
        : tracksCol.orderBy('listenedAt', descending: true);

    _tracksSubscription = deltaQuery.snapshots().listen((snapshot) {
      if (_currentUid != uid) return;

      bool changed = false;
      for (final change in snapshot.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;

        final data =
            ListenedTrackData.fromFirestore(docData, docId: change.doc.id);

        if (change.type == DocumentChangeType.removed) {
          if (_listenedTrackIds.remove(data.trackId)) {
            _listenedTracks.removeWhere((t) => t.trackId == data.trackId);
            changed = true;
          }
        } else {
          final idx =
              _listenedTracks.indexWhere((t) => t.trackId == data.trackId);
          if (idx != -1) {
            _listenedTracks[idx] = data;
          } else {
            _listenedTracks.insert(0, data);
            _listenedTrackIds.add(data.trackId);
          }
          changed = true;
        }
      }

      if (changed) {
        _totalTracksCount = _listenedTracks.length;
        notifyListeners();
        _storage.saveCachedListenedTracks(
          uid,
          _listenedTracks.map((t) => t.toJson()).toList(),
        );
      }
    }, onError: (e) {
      debugPrint('[LibraryProvider] Firestore delta sync error: $e');
    });

    // 4. Stats doc listener
    _statsSubscription = userDoc.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final stats = data?['stats'];
        if (stats is Map) {
          _totalTracksCount = stats['totalTracks'] ?? _listenedTracks.length;
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('[LibraryProvider] Firestore stats sync error: $e');
    });
  }

  void _pruneAlbumTrackCounts() {
    if (_albumTrackCounts.isEmpty) return;
    final activeAlbumIds = <String>{};
    for (final t in _listenedTracks) {
      if (t.albumId.isNotEmpty) activeAlbumIds.add(t.albumId);
    }
    final before = _albumTrackCounts.length;
    _albumTrackCounts
        .removeWhere((albumId, _) => !activeAlbumIds.contains(albumId));
    if (_albumTrackCounts.length < before) {
      _storage.saveAlbumTrackCounts(_albumTrackCounts);
      debugPrint(
          '[LibraryProvider] Pruned ${before - _albumTrackCounts.length} orphaned albumTrackCounts');
    }
  }

  void disconnectFirestore() {
    _currentUid = null;
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
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (_listenedTrackIds.contains(track.id)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

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
    _totalTracksCount = _listenedTracks.length;
    notifyListeners();

    // Cache locally immediately
    _storage.saveCachedListenedTracks(
      uid,
      _listenedTracks.map((t) => t.toJson()).toList(),
    );

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
      batch.set(
        userDoc,
        {
          'stats': {
            'totalTracks': FieldValue.increment(1),
          },
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('[LibraryProvider] markTrack rollback — Firestore failed: $e');
      _listenedTracks = prevTracks;
      _listenedTrackIds = prevIds;
      _totalTracksCount = prevCount;
      notifyListeners();
      _storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      );
    } finally {
      _endSync();
    }
  }

  Future<void> unmarkTrack(String trackId) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;
    if (!_listenedTrackIds.contains(trackId)) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update
    _listenedTracks.removeWhere((t) => t.trackId == trackId);
    _listenedTrackIds.remove(trackId);
    _totalTracksCount = _listenedTracks.length;
    notifyListeners();

    // Cache locally immediately
    _storage.saveCachedListenedTracks(
      uid,
      _listenedTracks.map((t) => t.toJson()).toList(),
    );

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      final batch = db.batch();
      batch.delete(userDoc.collection('listenedTracks').doc(trackId));
      batch.set(
        userDoc,
        {
          'stats': {
            'totalTracks': FieldValue.increment(-1),
          },
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('[LibraryProvider] unmarkTrack rollback — Firestore failed: $e');
      _listenedTracks = prevTracks;
      _listenedTrackIds = prevIds;
      _totalTracksCount = prevCount;
      notifyListeners();
      _storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      );
    } finally {
      _endSync();
    }
  }

  Future<void> markAlbumTracks(List<Track> tracks,
      {String? albumId, int? totalTracks}) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;

    if (albumId != null && totalTracks != null && totalTracks > 0) {
      registerAlbumTrackCount(albumId, totalTracks);
    } else if (tracks.isNotEmpty && tracks.first.albumId.isNotEmpty) {
      registerAlbumTrackCount(tracks.first.albumId, tracks.length);
    }

    final toMark =
        tracks.where((t) => !_listenedTrackIds.contains(t.id)).toList();
    if (toMark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

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
    _totalTracksCount = _listenedTracks.length;
    notifyListeners();

    // Cache locally immediately
    _storage.saveCachedListenedTracks(
      uid,
      _listenedTracks.map((t) => t.toJson()).toList(),
    );

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      const batchLimit = 450;

      for (var i = 0; i < newData.length; i += batchLimit) {
        final chunk = newData.sublist(
            i, i + batchLimit > newData.length ? newData.length : i + batchLimit);
        final batch = db.batch();

        for (final data in chunk) {
          batch.set(
            userDoc.collection('listenedTracks').doc(data.trackId),
            data.toFirestore(),
            SetOptions(merge: true),
          );
        }
        if (i == 0) {
          batch.set(
            userDoc,
            {
              'stats': {
                'totalTracks': FieldValue.increment(toMark.length),
              },
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] markAlbumTracks rollback — Firestore failed: $e');
      _listenedTracks = prevTracks;
      _listenedTrackIds = prevIds;
      _totalTracksCount = prevCount;
      notifyListeners();
      _storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      );
    } finally {
      _endSync();
    }
  }

  Future<void> unmarkAlbumTracks(List<String> trackIds) async {
    final uid = _currentUid ?? _firebase.currentUser?.uid;
    if (uid == null || !_canSyncToFirestore(uid)) return;

    final toUnmark =
        trackIds.where((id) => _listenedTrackIds.contains(id)).toList();
    if (toUnmark.isEmpty) return;

    // Snapshot pre-mutation state for rollback
    final prevTracks = List<ListenedTrackData>.from(_listenedTracks);
    final prevIds = Set<String>.from(_listenedTrackIds);
    final prevCount = _totalTracksCount;

    // Optimistic update
    _listenedTracks.removeWhere((t) => toUnmark.contains(t.trackId));
    _listenedTrackIds.removeAll(toUnmark);
    _totalTracksCount = _listenedTracks.length;
    notifyListeners();

    // Cache locally immediately
    _storage.saveCachedListenedTracks(
      uid,
      _listenedTracks.map((t) => t.toJson()).toList(),
    );

    _startSync();
    try {
      final db = _firebase.db;
      final userDoc = db.collection('users').doc(uid);
      const batchLimit = 450;

      for (var i = 0; i < toUnmark.length; i += batchLimit) {
        final chunk = toUnmark.sublist(
            i, i + batchLimit > toUnmark.length ? toUnmark.length : i + batchLimit);
        final batch = db.batch();

        for (final id in chunk) {
          batch.delete(userDoc.collection('listenedTracks').doc(id));
        }
        if (i == 0) {
          batch.set(
            userDoc,
            {
              'stats': {
                'totalTracks': FieldValue.increment(-toUnmark.length),
              },
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[LibraryProvider] unmarkAlbumTracks rollback — Firestore failed: $e');
      _listenedTracks = prevTracks;
      _listenedTrackIds = prevIds;
      _totalTracksCount = prevCount;
      notifyListeners();
      _storage.saveCachedListenedTracks(
        uid,
        _listenedTracks.map((t) => t.toJson()).toList(),
      );
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
