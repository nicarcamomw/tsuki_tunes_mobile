import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_catalog.dart';

final _log = Log.named('Discovery');

/// A song offered in discovery, with the artist it came from.
class DiscoveryCard {
  const DiscoveryCard({required this.track, this.because});

  final Track track;

  /// The artist of yours it was found through (null: from the charts).
  final String? because;
}

/// Discovery mode: a deck of songs the user hasn't heard, from artists near
/// the ones they love (related artists' top songs), or from the charts when
/// there's nothing to start from. Songs already shown don't come back.
class DiscoveryController extends ChangeNotifier {
  DiscoveryController({
    required MusicCatalog catalog,
    required List<Artist> Function() knownArtists,
    required List<String> Function() topArtistNames,
    required bool Function(String trackId) isListened,
    Random? random,
  })  : _catalog = catalog,
        _known = knownArtists,
        _topNames = topArtistNames,
        _isListened = isListened,
        _random = random ?? Random();

  final MusicCatalog _catalog;
  final List<Artist> Function() _known;
  final List<String> Function() _topNames;
  final bool Function(String trackId) _isListened;
  final Random _random;

  static const _seenKey = 'tsuki_discovery_seen';
  static const _seenKept = 1500;

  /// How many cards to keep ready ahead.
  static const ahead = 6;

  final List<DiscoveryCard> _cards = [];
  final Set<String> _queued = {};
  List<String> _seen = [];
  Set<String> _seenSet = {};
  List<Artist>? _seeds;
  bool _loading = false;
  bool _exhausted = false;
  bool _started = false;
  int _liked = 0;
  int _skipped = 0;

  List<DiscoveryCard> get cards => List.unmodifiable(_cards);
  bool get loading => _loading;

  /// Nothing new could be found (offline, or every source used up).
  bool get exhausted => _exhausted && _cards.isEmpty;
  int get liked => _liked;
  int get skipped => _skipped;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen = prefs.getStringList(_seenKey) ?? [];
      _seenSet = _seen.toSet();
    } catch (_) {}
    await _fill();
  }

  /// The top card was answered: saved ([liked]) or passed.
  void answer(DiscoveryCard card, {required bool liked}) {
    _cards.remove(card);
    _queued.remove(card.track.id);
    if (liked) {
      _liked++;
    } else {
      _skipped++;
    }
    _seen.add(card.track.id);
    _seenSet.add(card.track.id);
    if (_seen.length > _seenKept) {
      final drop = _seen.length - _seenKept;
      _seenSet.removeAll(_seen.take(drop));
      _seen = _seen.sublist(drop);
    }
    unawaited(_saveSeen());
    notifyListeners();
    if (_cards.length < ahead ~/ 2) unawaited(_fill());
  }

  /// Tries again after running dry (back online, say).
  Future<void> retry() async {
    _exhausted = false;
    await _fill();
  }

  Future<void> _saveSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, _seen);
    } catch (_) {}
  }

  bool _fresh(Track t) =>
      t.previewUrl.isNotEmpty && !_isListened(t.id) && !_seenSet.contains(t.id) && !_queued.contains(t.id);

  void _add(Track t, String? because) {
    _queued.add(t.id);
    _cards.add(DiscoveryCard(track: t, because: because));
  }

  Future<List<Artist>> _loadSeeds() async {
    final seeds = <String, Artist>{for (final a in _known()) a.id: a};
    // The most listened artists, found by name (the library keeps names).
    for (final name in _topNames().take(4)) {
      try {
        final found = await _catalog.searchArtists(name, limit: 1);
        if (found.isNotEmpty) seeds.putIfAbsent(found.first.id, () => found.first);
      } catch (_) {}
    }
    return seeds.values.toList()..shuffle(_random);
  }

  Future<void> _fill() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final seeds = _seeds ??= await _loadSeeds();
      final knownIds = seeds.map((a) => a.id).toSet();
      var attempts = 0;
      while (_cards.length < ahead && attempts < 8 && seeds.isNotEmpty) {
        attempts++;
        final seed = seeds[_random.nextInt(seeds.length)];
        final related = await _catalog.getRelatedArtists(seed.id, limit: 15);
        final fresh = related.where((a) => !knownIds.contains(a.id)).toList();
        if (fresh.isEmpty) continue;
        final pick = fresh[_random.nextInt(fresh.length)];
        final top = await _catalog.getArtistTopTracks(pick.id, limit: 8);
        final candidates = top.where(_fresh).toList()..shuffle(_random);
        for (final t in candidates.take(2)) {
          _add(t, seed.name);
        }
      }
      if (_cards.length < ahead) {
        // Nothing to start from, or the near artists ran dry: the charts.
        final chart = (await _catalog.getLargeChartTracks()).where(_fresh).toList()..shuffle(_random);
        for (final t in chart.take(ahead - _cards.length)) {
          _add(t, null);
        }
      }
      _exhausted = _cards.isEmpty;
    } catch (e) {
      _log.warning('filling the deck failed: $e');
      _exhausted = _cards.isEmpty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
