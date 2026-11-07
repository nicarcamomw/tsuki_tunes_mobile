import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/album_downloads.dart';
import '../../domain/entities/album.dart';

/// Albums saved for offline listening (their 30-second previews), and the
/// ones downloading now with how far along they are.
class AlbumDownloadsState extends ChangeNotifier {
  AlbumDownloadsState({AlbumDownloads? store}) : _store = store ?? AlbumDownloads.instance {
    unawaited(_store.ready().then((_) => notifyListeners()));
  }

  final AlbumDownloads _store;
  final Map<String, double> _progress = {};

  bool isDownloaded(String albumId) => _store.isDownloaded(albumId);

  /// 0..1 while [albumId] downloads; null otherwise.
  double? progressOf(String albumId) => _progress[albumId];

  /// The saved album with its songs, to open it offline.
  Album? savedAlbum(String albumId) => _store.album(albumId);

  int get savedAlbums => _store.albumIds.length;
  int get bytes => _store.bytes;

  /// Saves [album]'s previews. True when every song was saved.
  Future<bool> download(Album album) async {
    if (_progress.containsKey(album.id)) return false;
    _progress[album.id] = 0;
    notifyListeners();
    try {
      return await _store.download(album, onProgress: (done, total) {
        _progress[album.id] = total == 0 ? 1 : done / total;
        notifyListeners();
      });
    } finally {
      _progress.remove(album.id);
      notifyListeners();
    }
  }

  Future<void> remove(String albumId) async {
    await _store.remove(albumId);
    notifyListeners();
  }
}

final albumDownloadsProvider = ChangeNotifierProvider<AlbumDownloadsState>((ref) => AlbumDownloadsState());
