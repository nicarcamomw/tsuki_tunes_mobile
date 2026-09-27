import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../services/deezer_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final DeezerApiService _api = DeezerApiService();

  String _query = '';
  bool _isLoading = false;
  bool _hasError = false;
  String _activeCategory = 'all';
  int _searchGeneration = 0;

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
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
    final generation = ++_searchGeneration;
    notifyListeners();

    try {
      final results = await _api.search(_query);
      if (generation != _searchGeneration) return;
      _hasError = false;
      _tracks = results['tracks'] ?? [];
      _artists = results['artists'] ?? [];
      _albums = results['albums'] ?? [];
    } catch (e) {
      if (generation != _searchGeneration) return;
      debugPrint('Search error: $e');
      _hasError = true;
      _tracks = [];
      _artists = [];
      _albums = [];
    } finally {
      if (generation == _searchGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void retryLastSearch() {
    if (_query.isNotEmpty) search(_query);
  }

  void clear() {
    _query = '';
    _tracks = [];
    _artists = [];
    _albums = [];
    _isLoading = false;
    _hasError = false;
    _searchGeneration++;
    notifyListeners();
  }
}
