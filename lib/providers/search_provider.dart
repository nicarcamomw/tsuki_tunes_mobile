import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../services/deezer_api_service.dart';

class SearchProvider extends ChangeNotifier {
  final DeezerApiService _api = DeezerApiService();
  static const _historyKey = 'search_history';
  static const _maxHistory = 10;

  String _query = '';
  bool _isLoading = false;
  bool _hasError = false;
  String _activeCategory = 'all';
  int _searchGeneration = 0;

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];

  List<String> _searchHistory = [];

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get activeCategory => _activeCategory;
  List<Track> get tracks => _tracks;
  List<Artist> get artists => _artists;
  List<Album> get albums => _albums;
  List<String> get searchHistory => _searchHistory;

  SearchProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList(_historyKey) ?? [];
    notifyListeners();
  }

  Future<void> _saveToHistory(String query) async {
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > _maxHistory) {
      _searchHistory = _searchHistory.sublist(0, _maxHistory);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
    notifyListeners();
  }

  Future<void> removeFromHistory(String query) async {
    _searchHistory.remove(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    notifyListeners();
  }

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
      unawaited(_saveToHistory(cleanQuery));
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
