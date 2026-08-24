import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final DeezerApiService _api = DeezerApiService();

  String _query = '';
  bool _isLoading = false;
  String _activeCategory = 'all';

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];

  String get query => _query;
  bool get isLoading => _isLoading;
  String get activeCategory => _activeCategory;
  List<Track> get tracks => _tracks;
  List<Artist> get artists => _artists;
  List<Album> get albums => _albums;

  void setCategory(String category) {
    _activeCategory = category;
    notifyListeners();
  }

  Future<void> search(String queryText) async {
    final cleanQuery = queryText.trim();
    if (cleanQuery.length < 2) {
      clear();
      return;
    }

    _query = cleanQuery;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await _api.search(_query);
      _tracks = results['tracks'] ?? [];
      _artists = results['artists'] ?? [];
      _albums = results['albums'] ?? [];
    } catch (_) {
      _tracks = [];
      _artists = [];
      _albums = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _query = '';
    _tracks = [];
    _artists = [];
    _albums = [];
    _isLoading = false;
    notifyListeners();
  }
}
