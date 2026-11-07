import 'dart:math';

/// Where a suggestion comes from, for its icon.
enum SuggestionSource { history, library, catalog }

class SearchSuggestion {
  final String text;
  final SuggestionSource source;
  const SearchSuggestion(this.text, this.source);

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion && other.text == text && other.source == source;

  @override
  int get hashCode => Object.hash(text, source);

  @override
  String toString() => 'SearchSuggestion($text, $source)';
}

/// Suggestions while typing and "did you mean" for searches with typos.
///
/// Pure logic: the names to suggest are passed in (recent searches, the
/// user's artists and songs, the names in the current results), so it has
/// no network or storage dependency.
class SearchSuggestions {
  SearchSuggestions._();

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
  };
  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Lower case, no accents, punctuation turned into single spaces: "Beyoncé
  /// - Halo!" and "beyonce halo" fold the same.
  ///
  /// Remembered: the same library names are folded on every keystroke.
  static String fold(String s) {
    final cached = _folded[s];
    if (cached != null) return cached;
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final c in lower.split('')) {
      buf.write(_accents[c] ?? c);
    }
    final out = buf.toString().replaceAll(_nonWord, ' ').trim();
    if (_folded.length >= _maxFolded) _folded.clear();
    _folded[s] = out;
    return out;
  }

  static final Map<String, String> _folded = {};
  static const int _maxFolded = 50000;

  static List<String> _words(String folded) =>
      folded.isEmpty ? const [] : folded.split(' ');

  /// How well [candidate] completes [query] (both folded): 3 when it starts
  /// with it, 2 when one of its words does, 1 when it contains it (queries
  /// of 3+ characters), 0 when it doesn't match.
  static int _matchScore(String query, String candidate) {
    if (candidate.startsWith(query)) return 3;
    final qWords = _words(query);
    final cWords = _words(candidate);
    // Every query word starts a word of the candidate, the last one maybe
    // half typed: "bunny bad" finds "Bad Bunny".
    if (qWords.isNotEmpty &&
        qWords.every((q) => cWords.any((c) => c.startsWith(q)))) {
      return 2;
    }
    if (query.length >= 3 && candidate.contains(query)) return 1;
    return 0;
  }

  /// Up to [limit] completions of [query]: recent searches first, then the
  /// user's own names ([library], most relevant first), then names from the
  /// catalog ([catalog]). Better matches go first within each source; the
  /// query itself and repeats are left out.
  static List<SearchSuggestion> suggest(
    String query, {
    Iterable<String> history = const [],
    Iterable<String> library = const [],
    Iterable<String> catalog = const [],
    int limit = 6,
  }) {
    final q = fold(query);
    if (q.isEmpty) return const [];
    final seen = <String>{q};
    final out = <SearchSuggestion>[];

    void addFrom(Iterable<String> names, SuggestionSource source, int cap) {
      final scored = <(int, int, String)>[];
      var i = 0;
      for (final name in names) {
        final f = fold(name);
        final score = f.isEmpty ? 0 : _matchScore(q, f);
        if (score > 0) scored.add((score, i, name.trim()));
        i++;
      }
      // Best match first; ties keep the given order.
      scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
      var added = 0;
      for (final (_, _, name) in scored) {
        if (out.length >= limit || added >= cap) return;
        if (!seen.add(fold(name))) continue;
        out.add(SearchSuggestion(name, source));
        added++;
      }
    }

    addFrom(history, SuggestionSource.history, 3);
    addFrom(library, SuggestionSource.library, limit);
    addFrom(catalog, SuggestionSource.catalog, limit);
    return out;
  }

  /// Edit distance with swaps of two neighbouring letters counting as one
  /// (optimal string alignment): "metalica" is 1 from "metallica",
  /// "metlalica" too.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final rows = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var d = min(min(rows[i - 1][j] + 1, rows[i][j - 1] + 1), rows[i - 1][j - 1] + cost);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          d = min(d, rows[i - 2][j - 2] + 1);
        }
        rows[i][j] = d;
      }
    }
    return rows[a.length][b.length];
  }

  /// Typos allowed for a word or name of [length] letters: none below 4,
  /// one up to 7, two from 8 on.
  static int _allowed(int length) => length < 4 ? 0 : (length < 8 ? 1 : 2);

  /// A likely correction of [query] from [vocabulary] (artist, song and
  /// album names the user may have meant), or null. A whole name close
  /// enough wins ("metalica" → "Metallica"); otherwise each word is fixed
  /// on its own ("metalica one" → "metallica one"), only when the search
  /// found nothing, since a word missing from [vocabulary] may well be
  /// right. Null when the query already matches one of [resultNames] (what
  /// the search found), so a search that worked never gets a suggestion.
  static String? didYouMean(
    String query, {
    required Iterable<String> vocabulary,
    Iterable<String> resultNames = const [],
  }) {
    final q = fold(query);
    if (q.length < 4) return null;
    var hasResults = false;
    final resultWords = <String>{};
    for (final r in resultNames) {
      hasResults = true;
      final f = fold(r);
      if (f.isNotEmpty && (f.startsWith(q) || _matchScore(q, f) >= 2)) return null;
      resultWords.addAll(_words(f));
    }
    // Every word found somewhere in the results, split between an artist
    // and a song ("adele hello"): the search understood it.
    final qWords = _words(q);
    if (hasResults &&
        qWords.every((w) => resultWords.any((r) => r.startsWith(w)))) {
      return null;
    }

    final names = <String, String>{}; // folded -> as written
    for (final v in vocabulary) {
      final f = fold(v);
      if (f.isNotEmpty) names.putIfAbsent(f, () => v.trim());
    }
    if (names.isEmpty) return null;
    if (names.containsKey(q)) return null;

    // A whole name, compared without spaces ("badbuny" ~ "bad bunny").
    final qJoined = q.replaceAll(' ', '');
    String? best;
    var bestDistance = 1 << 30;
    names.forEach((f, original) {
      final joined = f.replaceAll(' ', '');
      if ((joined.length - qJoined.length).abs() > 2) return;
      // Same letters, only the spaces differ ("badbunny").
      final d = joined == qJoined ? 0 : distance(qJoined, joined);
      if (d == 0) {
        if (bestDistance > 0) {
          best = original;
          bestDistance = 0;
        }
        return;
      }
      if (d > 0 && d <= _allowed(joined.length) && d < bestDistance) {
        best = original;
        bestDistance = d;
      }
    });
    final queryWords = _words(q);
    // Word by word needs two words or more: a single one was compared
    // whole above, and fixing it alone would offer a piece of a name.
    if (best != null || hasResults || queryWords.length < 2) return best;

    // Word by word, against the words of every name.
    final vocabWords = <String>{for (final f in names.keys) ..._words(f)};
    var changed = false;
    final fixed = <String>[];
    for (final w in queryWords) {
      if (w.length < 4 || vocabWords.contains(w)) {
        fixed.add(w);
        continue;
      }
      String? bestWord;
      var bestWordDistance = 1 << 30;
      for (final v in vocabWords) {
        if ((v.length - w.length).abs() > 2) continue;
        final d = distance(w, v);
        if (d > 0 && d <= _allowed(v.length) && d < bestWordDistance) {
          bestWord = v;
          bestWordDistance = d;
        }
      }
      if (bestWord != null) {
        fixed.add(bestWord);
        changed = true;
      } else {
        fixed.add(w);
      }
    }
    return changed ? fixed.join(' ') : null;
  }
}
