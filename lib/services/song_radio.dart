import 'dart:async';
import 'dart:math';

import '../models/track.dart';
import 'deezer_api_service.dart';
import 'lastfm_service.dart';

enum RadioMode { familiar, balanced, adventurous }

enum RadioSource { seed, lastfm, deezer }

/// Why a track is in the radio: shown in the queue ("Similar to X").
class RadioReason {
  final RadioSource source;
  final String seedTitle;
  final String seedArtist;
  const RadioReason(this.source, this.seedTitle, this.seedArtist);
}

typedef SimilarTracksFetcher = Future<List<LastFmSimilarTrack>> Function(
    String artist, String title);
typedef ArtistRadioFetcher = Future<List<Track>> Function(String artistId);
typedef TrackSearcher = Future<List<Track>> Function(String query);

class _Candidate {
  final Track track;
  final RadioReason reason;
  final double score;
  _Candidate(this.track, this.reason, this.score);
}

/// Endless song radio mixing Last.fm `track.getSimilar` (song-level
/// similarity, names only) with Deezer `/artist/{id}/radio` (playable, more
/// variety). It learns during the session: skipped artists fade out, songs
/// heard through become new seeds, so the radio drifts the way you steer it.
///
/// Pure logic with injectable sources, no Flutter dependency.
class SongRadio {
  SongRadio({
    required this.seed,
    RadioMode mode = RadioMode.balanced,
    SimilarTracksFetcher? similar,
    ArtistRadioFetcher? artistRadio,
    TrackSearcher? search,
    bool? useLastFm,
    Random? random,
  })  : _mode = mode,
        _similar = similar ?? LastFmService.getSimilarTracks,
        _artistRadio = artistRadio ?? DeezerApiService().getArtistRadio,
        _search = search ?? _defaultSearch,
        usesLastFm = useLastFm ?? LastFmService.isConfigured,
        _rng = random ?? Random() {
    _seedArtistKey = artistKeyOf(seed);
    _markUsed(seed);
    _reasons[seed.id] =
        RadioReason(RadioSource.seed, seed.title, primaryArtist(seed));
  }

  final Track seed;
  final bool usesLastFm;
  final SimilarTracksFetcher _similar;
  final ArtistRadioFetcher _artistRadio;
  final TrackSearcher _search;
  final Random _rng;
  RadioMode _mode;
  late final String _seedArtistKey;

  final Set<String> _usedIds = {};
  final Set<String> _usedKeys = {};
  final List<_Candidate> _buffer = [];
  final Map<String, RadioReason> _reasons = {};
  final Map<String, double> _affinity = {};
  final Map<String, int> _skips = {};
  final Set<String> _banned = {};
  final Set<String> _bannedNames = {};
  final List<Track> _liked = [];
  final Map<String, int> _seedUses = {};
  final List<String> _recentArtists = [];
  final Set<String> _heardArtists = {};
  Track? _forcedSeed;
  Future<void>? _inflight;

  // Last.fm name -> Deezer track lookups, shared across radios.
  static final Map<String, Track?> _resolveCache = {};

  static const int _maxBuffer = 60;
  static const int _maxLiked = 25;

  RadioMode get mode => _mode;
  RadioReason? reasonFor(String trackId) => _reasons[trackId];
  bool isBanned(Track t) => _banned.contains(artistKeyOf(t));

  /// Tracks already in the queue (e.g. restored ones) must never come back.
  void markQueued(Iterable<Track> tracks) => tracks.forEach(_markUsed);

  // ---------------------------------------------------------------------------
  // Persistence: the radio survives app restarts with what it learned
  // ---------------------------------------------------------------------------

  static const int _persistVersion = 1;

  /// [keepReasonsFor] limits saved "why" labels to tracks still queued.
  Map<String, dynamic> toJson({Iterable<String>? keepReasonsFor}) {
    final keep = keepReasonsFor?.toSet();
    List<String> lastN(Iterable<String> items, int n) {
      final list = items.toList();
      return list.length <= n ? list : list.sublist(list.length - n);
    }

    return {
      'v': _persistVersion,
      'seed': seed.toJson(),
      'mode': _mode.index,
      'reasons': {
        for (final e in _reasons.entries)
          if (keep == null || keep.contains(e.key))
            e.key: {
              's': e.value.source.index,
              't': e.value.seedTitle,
              'a': e.value.seedArtist,
            },
      },
      'affinity': _affinity,
      'skips': _skips,
      'banned': _banned.toList(),
      'bannedNames': _bannedNames.toList(),
      'liked': [for (final t in _liked) t.toJson()],
      'seedUses': _seedUses,
      'recent': _recentArtists,
      // Insertion-ordered sets: keep the most recent entries.
      'heard': lastN(_heardArtists, 300),
      'usedIds': lastN(_usedIds, 500),
      'usedKeys': lastN(_usedKeys, 500),
    };
  }

  /// Restores a radio saved with [toJson]; null if the data is unusable.
  static SongRadio? fromJson(
    Map<String, dynamic> json, {
    SimilarTracksFetcher? similar,
    ArtistRadioFetcher? artistRadio,
    TrackSearcher? search,
    bool? useLastFm,
    Random? random,
  }) {
    try {
      final seedRaw = json['seed'];
      if (seedRaw is! Map || json['v'] != _persistVersion) return null;
      final modeIndex = json['mode'];
      final radio = SongRadio(
        seed: Track.fromJson(Map<String, dynamic>.from(seedRaw)),
        mode: modeIndex is int && modeIndex >= 0 && modeIndex < RadioMode.values.length
            ? RadioMode.values[modeIndex]
            : RadioMode.balanced,
        similar: similar,
        artistRadio: artistRadio,
        search: search,
        useLastFm: useLastFm,
        random: random,
      );

      final reasons = json['reasons'];
      if (reasons is Map) {
        for (final e in reasons.entries) {
          final v = e.value;
          final s = v is Map ? v['s'] : null;
          if (s is int && s >= 0 && s < RadioSource.values.length) {
            radio._reasons[e.key.toString()] = RadioReason(
                RadioSource.values[s], '${v['t'] ?? ''}', '${v['a'] ?? ''}');
          }
        }
      }
      final liked = json['liked'];
      if (liked is List) {
        for (final l in liked) {
          if (l is Map) {
            radio._liked.add(Track.fromJson(Map<String, dynamic>.from(l)));
          }
        }
      }
      radio._affinity.addAll(_doubleMap(json['affinity']));
      radio._skips.addAll(_intMap(json['skips']));
      radio._seedUses.addAll(_intMap(json['seedUses']));
      radio._banned.addAll(_strings(json['banned']));
      radio._bannedNames.addAll(_strings(json['bannedNames']));
      radio._recentArtists.addAll(_strings(json['recent']));
      radio._heardArtists.addAll(_strings(json['heard']));
      radio._usedIds.addAll(_strings(json['usedIds']));
      radio._usedKeys.addAll(_strings(json['usedKeys']));
      return radio;
    } catch (_) {
      return null;
    }
  }

  static Map<String, double> _doubleMap(Object? raw) => raw is Map
      ? {
          for (final e in raw.entries)
            if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
        }
      : {};

  static Map<String, int> _intMap(Object? raw) => raw is Map
      ? {
          for (final e in raw.entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        }
      : {};

  static Iterable<String> _strings(Object? raw) =>
      raw is List ? raw.map((e) => e.toString()) : const [];

  // ---------------------------------------------------------------------------
  // Steering
  // ---------------------------------------------------------------------------

  void setMode(RadioMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _buffer.clear();
  }

  /// [fraction] is how much of the track was heard before moving on.
  void registerPlayed(Track t, double fraction) {
    final a = artistKeyOf(t);
    if (fraction < 0.3) {
      _affinity[a] = (_affinity[a] ?? 0) - 1;
      final skips = (_skips[a] ?? 0) + 1;
      _skips[a] = skips;
      if (skips >= 2 && a != _seedArtistKey) _ban(t);
    } else if (fraction >= 0.7) {
      _affinity[a] = (_affinity[a] ?? 0) + 1;
      _skips[a] = 0;
      if (t.id != seed.id && !_liked.any((l) => l.id == t.id)) {
        _liked.add(t);
        if (_liked.length > _maxLiked) _liked.removeAt(0);
      }
    }
  }

  /// Next refill grows from [t]; pending picks are discarded.
  void moreLikeThis(Track t) {
    final a = artistKeyOf(t);
    _affinity[a] = (_affinity[a] ?? 0) + 2;
    _skips[a] = 0;
    _liked.removeWhere((l) => l.id == t.id);
    if (t.id != seed.id) _liked.add(t);
    _forcedSeed = t;
    _buffer.clear();
  }

  void lessLikeThis(Track t) => _ban(t);

  void _ban(Track t) {
    final a = artistKeyOf(t);
    _banned.add(a);
    _bannedNames.add(norm(primaryArtist(t)));
    _liked.removeWhere((l) => artistKeyOf(l) == a);
    _buffer.removeWhere((c) => artistKeyOf(c.track) == a);
  }

  // ---------------------------------------------------------------------------
  // Producing tracks
  // ---------------------------------------------------------------------------

  /// Up to [count] new tracks, never repeating a song (across versions) and
  /// keeping the same artist apart.
  Future<List<Track>> nextBatch({int count = 8}) async {
    var dry = 0;
    for (var round = 0; round < 4 && _buffer.length < count + 4; round++) {
      final before = _buffer.length;
      await _refill();
      if (_buffer.length == before && ++dry >= 2) break;
    }
    return _take(count);
  }

  Future<void> _refill() =>
      _inflight ??= _doRefill().whenComplete(() => _inflight = null);

  Future<void> _doRefill() async {
    final from = _pickSeed();
    _forcedSeed = null;
    _seedUses.update(from.id, (v) => v + 1, ifAbsent: () => 1);

    final results = await Future.wait([_fromLastFm(from), _fromDeezer(from)]);
    final lastfm = results[0];
    final deezer = results[1];
    final (lfStep, dzStep) = switch (_mode) {
      RadioMode.familiar => (2, 1),
      RadioMode.balanced => (1, 1),
      RadioMode.adventurous => (1, 2),
    };
    var i = 0, j = 0;
    while (i < lastfm.length || j < deezer.length) {
      for (var k = 0; k < lfStep && i < lastfm.length; k++) {
        _admit(lastfm[i++]);
      }
      for (var k = 0; k < dzStep && j < deezer.length; k++) {
        _admit(deezer[j++]);
      }
    }
  }

  Track _pickSeed() {
    final forced = _forcedSeed;
    if (forced != null) return forced;
    if (_liked.isEmpty) return seed;

    final pool = [seed, ..._liked];
    final weights = <double>[];
    for (var i = 0; i < pool.length; i++) {
      final recency = i == 0 ? 0.0 : i / _liked.length; // newest liked = 1
      final base = switch (_mode) {
        RadioMode.familiar => i == 0 ? 4.0 : 0.6 + recency,
        RadioMode.balanced => i == 0 ? 1.5 : 0.8 + recency * 1.5,
        RadioMode.adventurous => i == 0 ? 0.4 : 0.5 + recency * 3,
      };
      weights.add(base / (1 + (_seedUses[pool[i].id] ?? 0) * 0.7));
    }
    var roll = _rng.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return pool[i];
    }
    return pool.last;
  }

  Future<List<_Candidate>> _fromDeezer(Track from) async {
    if (from.artistId.isEmpty) return const [];
    List<Track> tracks;
    try {
      tracks = await _artistRadio(from.artistId);
    } catch (_) {
      return const [];
    }
    final reason =
        RadioReason(RadioSource.deezer, from.title, primaryArtist(from));
    return [
      for (var i = 0; i < tracks.length; i++)
        _Candidate(tracks[i], reason, _score(tracks[i], 0.55 - i * 0.008)),
    ];
  }

  Future<List<_Candidate>> _fromLastFm(Track from) async {
    if (!usesLastFm) return const [];
    List<LastFmSimilarTrack> similar;
    try {
      similar = await _similar(primaryArtist(from), cleanTitle(from.title));
    } catch (_) {
      return const [];
    }
    final pending = _buffer.map((c) => songKey(c.track)).toSet();
    final fresh = similar.where((s) {
      final key = '${norm(s.artist)}|${norm(s.title)}';
      return !_usedKeys.contains(key) &&
          !pending.contains(key) &&
          !_bannedNames.contains(norm(s.artist));
    }).toList();
    if (fresh.isEmpty) return const [];

    final reason =
        RadioReason(RadioSource.lastfm, from.title, primaryArtist(from));
    final resolved = await _resolveAll(_sampleSimilar(fresh, 10));
    return [
      for (final (s, t) in resolved) _Candidate(t, reason, _score(t, 0.35 + s.match)),
    ];
  }

  /// Familiar sticks to the closest matches; adventurous skips the obvious
  /// ones and digs deeper into the list.
  List<LastFmSimilarTrack> _sampleSimilar(
      List<LastFmSimilarTrack> list, int count) {
    final (start, end) = switch (_mode) {
      RadioMode.familiar => (0, 20),
      RadioMode.balanced => (0, 40),
      // Skipping the obvious picks only makes sense with a long list.
      RadioMode.adventurous => (list.length > 15 ? 5 : 0, 60),
    };
    final window = list.sublist(start, min(end, list.length));
    final picks = <LastFmSimilarTrack>[];
    final weights = [
      for (final s in window)
        _mode == RadioMode.adventurous ? 0.4 + (1 - s.match) * 0.4 : 0.15 + s.match,
    ];
    while (picks.length < count && window.isNotEmpty) {
      var roll = _rng.nextDouble() * weights.fold(0.0, (a, b) => a + b);
      var idx = window.length - 1;
      for (var i = 0; i < window.length; i++) {
        roll -= weights[i];
        if (roll <= 0) {
          idx = i;
          break;
        }
      }
      picks.add(window.removeAt(idx));
      weights.removeAt(idx);
    }
    return picks;
  }

  Future<List<(LastFmSimilarTrack, Track)>> _resolveAll(
      List<LastFmSimilarTrack> picks) async {
    final out = <(LastFmSimilarTrack, Track)>[];
    // Bounded concurrency keeps us under Deezer's 50 requests / 5 s.
    for (var i = 0; i < picks.length; i += 4) {
      final chunk = picks.sublist(i, min(i + 4, picks.length));
      final tracks = await Future.wait(chunk.map(_resolve));
      for (var k = 0; k < chunk.length; k++) {
        final t = tracks[k];
        if (t != null) out.add((chunk[k], t));
      }
    }
    return out;
  }

  Future<Track?> _resolve(LastFmSimilarTrack s) async {
    final key = '${norm(s.artist)}|${norm(s.title)}';
    if (_resolveCache.containsKey(key)) return _resolveCache[key];

    final artist = s.artist.replaceAll('"', '');
    final title = s.title.replaceAll('"', '');
    Track? found;
    for (final query in ['artist:"$artist" track:"$title"', '$artist $title']) {
      List<Track> results;
      try {
        results = await _search(query);
      } catch (_) {
        results = const [];
      }
      found = _bestMatch(results, s);
      if (found != null) break;
    }

    if (_resolveCache.length > 500) _resolveCache.remove(_resolveCache.keys.first);
    _resolveCache[key] = found;
    return found;
  }

  static final RegExp _variant = RegExp(
      r'\b(live|en vivo|karaoke|instrumental|acoustic|acustic|remix|cover|tribute|8-bit|lullaby)\b');

  Track? _bestMatch(List<Track> results, LastFmSimilarTrack s) {
    final wantArtist = norm(s.artist);
    final wantTitle = norm(s.title);
    final wantsVariant = _variant.hasMatch(s.title.toLowerCase());
    Track? best;
    var bestScore = -100;
    for (final t in results) {
      if (t.previewUrl.isEmpty) continue;
      final artist = norm(primaryArtist(t));
      final allArtists = norm(t.artistName);
      final artistOk = artist == wantArtist ||
          allArtists.contains(wantArtist) ||
          (artist.length >= 3 && wantArtist.contains(artist));
      if (!artistOk) continue;
      final title = norm(t.title);
      final titleOk = title == wantTitle ||
          title.startsWith(wantTitle) ||
          wantTitle.startsWith(title);
      if (!titleOk || title.isEmpty) continue;

      var score = title == wantTitle ? 3 : 1;
      if (!wantsVariant && _variant.hasMatch(t.title.toLowerCase())) score -= 3;
      if (score > bestScore) {
        best = t;
        bestScore = score;
      }
    }
    return best;
  }

  double _score(Track t, double base) {
    final a = artistKeyOf(t);
    final isSeedArtist = a == _seedArtistKey;
    return base +
        (_affinity[a] ?? 0) * 0.25 +
        switch (_mode) {
          RadioMode.familiar => isSeedArtist ? 0.25 : 0,
          RadioMode.balanced => 0,
          RadioMode.adventurous =>
            isSeedArtist ? -0.5 : (_heardArtists.contains(a) ? -0.2 : 0.15),
        };
  }

  void _admit(_Candidate c) {
    final t = c.track;
    if (_buffer.length >= _maxBuffer) return;
    if (t.id.isEmpty || t.previewUrl.isEmpty) return;
    if (_usedIds.contains(t.id) || _banned.contains(artistKeyOf(t))) return;
    final key = songKey(t);
    if (_usedKeys.contains(key)) return;
    if (_buffer.any((b) => b.track.id == t.id || songKey(b.track) == key)) {
      return;
    }
    _buffer.add(c);
  }

  List<Track> _take(int count) {
    final spacing = switch (_mode) {
      RadioMode.familiar => 2,
      RadioMode.balanced => 3,
      RadioMode.adventurous => 4,
    };
    final out = <Track>[];
    while (out.length < count && _buffer.isNotEmpty) {
      var bestI = 0;
      var best = double.negativeInfinity;
      for (var i = 0; i < _buffer.length; i++) {
        final c = _buffer[i];
        // Mild FIFO preference keeps the source interleaving.
        var s = c.score - i * 0.03 + _rng.nextDouble() * 0.2;
        final pos = _recentArtists.lastIndexOf(artistKeyOf(c.track));
        if (pos != -1) {
          final gap = _recentArtists.length - pos;
          s -= gap <= spacing ? 10 : 1.0 / gap;
        }
        if (s > best) {
          best = s;
          bestI = i;
        }
      }
      // Only same-artist picks left: better to wait for the next refill.
      if (best < -5 && out.isNotEmpty) break;

      final c = _buffer.removeAt(bestI);
      out.add(c.track);
      _markUsed(c.track);
      _reasons[c.track.id] = c.reason;
      final a = artistKeyOf(c.track);
      _recentArtists.add(a);
      if (_recentArtists.length > 12) _recentArtists.removeAt(0);
      _heardArtists.add(a);
    }
    return out;
  }

  void _markUsed(Track t) {
    _usedIds.add(t.id);
    _usedKeys.add(songKey(t));
  }

  // ---------------------------------------------------------------------------
  // Matching helpers
  // ---------------------------------------------------------------------------

  static Future<List<Track>> _defaultSearch(String query) async {
    try {
      return await DeezerApiService().searchTracks(query, limit: 6);
    } catch (_) {
      return const [];
    }
  }

  static String primaryArtist(Track t) {
    if (t.contributors.isNotEmpty && t.contributors.first.name.isNotEmpty) {
      return t.contributors.first.name;
    }
    return t.artistName.split(RegExp(r',\s*')).first;
  }

  String artistKeyOf(Track t) =>
      t.artistId.isNotEmpty ? t.artistId : 'n:${norm(primaryArtist(t))}';

  /// One key per song regardless of version: "Toxicity (Remastered)" and
  /// "Toxicity - Live" collapse to the same entry.
  static String songKey(Track t) => '${norm(primaryArtist(t))}|${norm(t.title)}';

  static final RegExp _brackets = RegExp(r'\s*[\(\[\{][^\)\]\}]*[\)\]\}]');
  static final RegExp _versionSuffix = RegExp(
      r'\s+-\s+[^-]*(remaster|live|version|edit|mix|mono|stereo|acoustic|demo|radio)[^-]*$',
      caseSensitive: false);
  static final RegExp _feat =
      RegExp(r'\s+(feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false);
  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  static String cleanTitle(String title) => title
      .replaceAll(_brackets, '')
      .replaceAll(_versionSuffix, '')
      .replaceAll(_feat, '')
      .trim();

  static String norm(String input) {
    final lowered = cleanTitle(input.toLowerCase());
    final sb = StringBuffer();
    for (final ch in lowered.split('')) {
      sb.write(_accents[ch] ?? ch);
    }
    return sb
        .toString()
        .replaceAll('&', ' and ')
        .replaceAll(_nonWord, ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
