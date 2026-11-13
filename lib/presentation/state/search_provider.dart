import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../data/datasources/deezer_api_service.dart';
import '../../data/datasources/lastfm_service.dart';
import '../../data/datasources/lyrics_service.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/lyrics_search_result.dart';
import '../../domain/entities/track.dart';
import '../../domain/logic/search_suggestions.dart';

final _log = Log.named('Search');

class SearchProvider extends ChangeNotifier {
  final DeezerApiService _api;
  final LyricsService _lyricsService;
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

  List<LyricsSearchResult> _lyricsResults = [];
  bool _isLyricsLoading = false;
  bool _hasLyricsError = false;
  int _lyricsSearchGeneration = 0;

  List<String> _searchHistory = [];

  // Names "did you mean" can offer (not the history, which keeps typos):
  // the user's artists, songs and albums
  // (see [setLibraryNames]) and the chart artists, once loaded.
  List<String> _libraryNames = const [];
  List<String> _chartNames = const [];
  bool _chartNamesRequested = false;
  String? _didYouMean;

  /// Artist names a typo-tolerant search finds for a query (Last.fm when it
  /// has a key), asked only when Deezer finds nothing.
  final Future<List<String>> Function(String query) _fuzzyArtistNames;

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get activeCategory => _activeCategory;
  List<Track> get tracks => _tracks;
  List<Artist> get artists => _artists;
  List<Album> get albums => _albums;
  List<LyricsSearchResult> get lyricsResults => _lyricsResults;
  bool get isLyricsLoading => _isLyricsLoading;
  bool get hasLyricsError => _hasLyricsError;
  List<String> get searchHistory => _searchHistory;

  /// A likely correction of the last query, or null.
  String? get didYouMean => _didYouMean;

  /// Names of the current results, for suggestions while typing.
  Iterable<String> get resultNames sync* {
    for (final a in _artists) {
      yield a.name;
    }
    for (final t in _tracks) {
      yield t.title;
    }
    for (final a in _albums) {
      yield a.title;
    }
  }

  /// [api] and [lyrics] come from get_it (app_providers); a test can hand
  /// in fakes. Left out, they're the app's own instances.
  SearchProvider({
    DeezerApiService? api,
    LyricsService? lyrics,
    Future<List<String>> Function(String query)? fuzzyArtistNames,
  })  : _api = api ?? DeezerApiService(),
        _lyricsService = lyrics ?? LyricsService(),
        _fuzzyArtistNames = fuzzyArtistNames ?? LastFmService.searchArtistNames {
    _loadHistory();
  }

  /// The user's artists, songs and albums, most relevant first: "did you
  /// mean" corrects towards them.
  void setLibraryNames(List<String> names) => _libraryNames = names;

  Future<void> _loadChartNames() async {
    if (_chartNamesRequested) return;
    _chartNamesRequested = true;
    try {
      final artists = await _api.getChartArtists();
      _chartNames = [for (final a in artists) a.name];
    } catch (e) {
      _log.warning('chart names for suggestions: $e');
    }
  }

  String? _correction(String query, [Iterable<String> extra = const []]) =>
      SearchSuggestions.didYouMean(
        query,
        vocabulary: [..._libraryNames, ..._chartNames, ...extra],
        resultNames: resultNames,
      );

  /// Works out "did you mean" for [query] once its results are in. With no
  /// results and nothing close among the known names, asks the
  /// typo-tolerant search too.
  Future<void> _suggestCorrection(String query, int generation) async {
    await _loadChartNames();
    if (generation != _searchGeneration) return;
    var correction = _correction(query);
    final empty = _artists.isEmpty && _tracks.isEmpty && _albums.isEmpty;
    if (correction == null && empty) {
      try {
        final names = await _fuzzyArtistNames(query);
        if (generation != _searchGeneration) return;
        correction = _correction(query, names);
      } catch (e) {
        _log.warning('fuzzy artist names: $e');
      }
    }
    if (generation != _searchGeneration || correction == _didYouMean) return;
    _didYouMean = correction;
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList(_historyKey) ?? [];
    notifyListeners();
  }

  // When the last entry was saved, to tell a query still being typed from
  // a new search.
  DateTime? _lastSavedAt;

  Future<void> _saveToHistory(String query) async {
    // Results arrive as the user types (400 ms debounce), so a slow typist
    // saved "bad", then "bad bun", then "bad bunny". Within a short while,
    // a query that extends or trims the last entry replaces it.
    final now = DateTime.now();
    final last = _lastSavedAt;
    if (last != null &&
        now.difference(last) < const Duration(seconds: 30) &&
        _searchHistory.isNotEmpty) {
      final top = _searchHistory.first.toLowerCase();
      final q = query.toLowerCase();
      if (q.startsWith(top) || top.startsWith(q)) _searchHistory.removeAt(0);
    }
    _lastSavedAt = now;
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
    _didYouMean = null;
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
      unawaited(_suggestCorrection(cleanQuery, generation));
    } catch (e) {
      if (generation != _searchGeneration) return;
      _log.severe('Search error: $e');
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

  Future<void> searchLyrics(String queryText) async {
    final cleanQuery = queryText.trim();
    if (cleanQuery.length < 3) {
      _lyricsResults = [];
      _isLyricsLoading = false;
      _hasLyricsError = false;
      notifyListeners();
      return;
    }

    _query = cleanQuery;
    _isLyricsLoading = true;
    _hasLyricsError = false;
    final generation = ++_lyricsSearchGeneration;
    notifyListeners();

    try {
      final results = await _lyricsService.searchByLyrics(cleanQuery);
      if (generation != _lyricsSearchGeneration) return;
      _lyricsResults = results;
      _hasLyricsError = false;
    } catch (e) {
      if (generation != _lyricsSearchGeneration) return;
      _log.severe('Lyrics search error: $e');
      _hasLyricsError = true;
      _lyricsResults = [];
    } finally {
      if (generation == _lyricsSearchGeneration) {
        _isLyricsLoading = false;
        notifyListeners();
      }
    }
  }

  void retryLastSearch() {
    if (_query.isNotEmpty) search(_query);
  }

  void retryLyricsSearch() {
    if (_query.isNotEmpty) searchLyrics(_query);
  }

  void clear() {
    _query = '';
    _tracks = [];
    _artists = [];
    _albums = [];
    _lyricsResults = [];
    _isLoading = false;
    _hasError = false;
    _isLyricsLoading = false;
    _hasLyricsError = false;
    _didYouMean = null;
    _searchGeneration++;
    _lyricsSearchGeneration++;
    notifyListeners();
  }
}
