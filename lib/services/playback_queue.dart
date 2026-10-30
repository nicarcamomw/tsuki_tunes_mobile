import 'dart:math';
import '../models/repeat_mode.dart';
import '../models/track.dart';

/// What the player should do after a next/previous request.
enum QueueStepKind {
  /// Play the track at [QueueStep.index] (already selected as current).
  play,

  /// Restart the current track instead of moving.
  seekToStart,

  /// Nothing playable (offline with no cached tracks).
  unavailable,
}

class QueueStep {
  final QueueStepKind kind;
  final int index;

  const QueueStep._(this.kind, [this.index = -1]);
  const QueueStep.play(int index) : this._(QueueStepKind.play, index);
  static const seekToStart = QueueStep._(QueueStepKind.seekToStart);
  static const unavailable = QueueStep._(QueueStepKind.unavailable);
}

/// The queue as it was, to undo an edit (removing, clearing, moving).
/// Positions are kept as track ids so it restores even if the song changed.
class QueueSnapshot {
  final List<Track> tracks;
  final List<String> history;
  final List<String> userQueue;
  final List<String> shufflePicks;
  final bool shuffle;

  const QueueSnapshot._(
      this.tracks, this.history, this.userQueue, this.shufflePicks, this.shuffle);
}

/// Playback queue state and navigation rules (order, shuffle, repeat,
/// history), with no audio or Flutter dependencies.
///
/// [canPlay] tells which tracks are playable right now; when offline only
/// cached tracks are, and navigation skips the rest.
class PlaybackQueue {
  PlaybackQueue({Random? random}) : _rng = random ?? Random();

  final Random _rng;

  List<Track> _tracks = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;

  // Pre-picked next index while shuffling, so prefetching and playback
  // target the same track.
  int? _nextShuffleIndex;
  // Shuffle picks after that one, made ahead by [peekUpcoming] (so Spotify
  // can be told what follows) and used in this order by [next].
  final List<int> _shuffleLookahead = [];

  void _forgetShufflePicks() {
    _nextShuffleIndex = null;
    _shuffleLookahead.clear();
  }

  /// The shuffle picks made ahead, as ids (they survive index shifts).
  List<String> _pickIds() => [
        for (final i in [
          if (_nextShuffleIndex != null) _nextShuffleIndex!,
          ..._shuffleLookahead,
        ])
          if (_isValid(i) && i != _currentIndex) _tracks[i].id,
      ];

  /// Makes [ids] the shuffle picks, in that order.
  void _setPicks(Iterable<String> ids) {
    _forgetShufflePicks();
    final seen = <int>{_currentIndex};
    for (final id in ids) {
      final i = _tracks.indexWhere((t) => t.id == id);
      if (i == -1 || !seen.add(i)) continue;
      if (_nextShuffleIndex == null) {
        _nextShuffleIndex = i;
      } else {
        _shuffleLookahead.add(i);
      }
    }
  }

  /// Keeps the shuffle picks made ahead with the user's queue first, in its
  /// order, as it plays. [first] goes before even that (running mode).
  void _queueFirstInPicks({String? first}) {
    if (!_isShuffle) return;
    final queued = [
      for (final id in _userQueue)
        if (id != current?.id && id != first) id
    ];
    _setPicks([
      if (first != null) first,
      ...queued,
      ..._pickIds().where((id) => id != first && !_userQueue.contains(id)),
    ]);
  }

  /// Where index [x] ends up after the track at [from] moves to [to].
  static int _shifted(int x, int from, int to) {
    if (x == from) return to;
    if (from < to && x > from && x <= to) return x - 1;
    if (to < from && x >= to && x < from) return x + 1;
    return x;
  }

  /// Moves on to the next memoized shuffle pick, if any.
  void _advanceShufflePick() {
    _nextShuffleIndex = null;
    while (_shuffleLookahead.isNotEmpty) {
      final i = _shuffleLookahead.removeAt(0);
      if (_isValid(i) && i != _currentIndex) {
        _nextShuffleIndex = i;
        return;
      }
    }
  }

  // Indices played before the current one (shuffle "previous").
  final List<int> _history = [];
  static const int _maxHistory = 50;

  // Recently played artists/albums, to avoid repeats when shuffling.
  final List<String> _artistHistory = [];
  final List<String> _albumHistory = [];
  static const int _shuffleHistorySize = 5;

  // Ids the user queued by hand, in play order. Like Spotify's queue they
  // play right after the current track, ahead of the rest of the album or
  // playlist (shuffled or not), and carry over when a new one starts.
  final List<String> _userQueue = [];

  List<Track> get tracks => _tracks;
  int get currentIndex => _currentIndex;
  bool get isEmpty => _tracks.isEmpty;
  int get length => _tracks.length;
  bool get isShuffle => _isShuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  int? get nextShuffleIndex => _nextShuffleIndex;
  List<int> get history => List.unmodifiable(_history);
  List<String> get userQueue => List.unmodifiable(_userQueue);
  bool isUserQueued(String trackId) => _userQueue.contains(trackId);

  Track? get current => _currentIndex >= 0 && _currentIndex < _tracks.length
      ? _tracks[_currentIndex]
      : null;

  bool _isValid(int? i) => i != null && i >= 0 && i < _tracks.length;

  // --- Building the queue ---

  /// Restores a persisted queue without touching history.
  void restore(List<Track> tracks, int index) {
    _tracks = List.of(tracks);
    _currentIndex = _isValid(index) ? index : (tracks.isEmpty ? -1 : 0);
    _userQueue.clear();
  }

  /// Makes [track] current, replacing the queue with [newQueue] if given,
  /// otherwise selecting it in (or appending it to) the current queue.
  /// Tracks still waiting in the user's queue stay up next either way.
  void select(Track track, {List<Track>? newQueue}) {
    final pending = _pendingUserQueue(except: track.id);
    // Playing the track [next] just moved to: the shuffle picks made ahead
    // (and the songs downloaded for them) still hold.
    final keepPicks = newQueue == null && current?.id == track.id;
    // Picking one of the upcoming shuffle picks: the ones after it follow.
    final picks = _pickIds();
    final pickedAt = newQueue == null ? picks.indexOf(track.id) : -1;
    if (newQueue != null && newQueue.isNotEmpty) {
      _tracks = List.of(newQueue);
      _currentIndex = _tracks.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _tracks.insert(0, track);
        _currentIndex = 0;
      }
      _history.clear();
    } else {
      final idx = _tracks.indexWhere((t) => t.id == track.id);
      if (idx == -1) {
        _tracks.add(track);
        _currentIndex = _tracks.length - 1;
      } else {
        _currentIndex = idx;
      }
    }
    if (pickedAt != -1) {
      _setPicks(picks.sublist(pickedAt + 1));
    } else if (!keepPicks) {
      _forgetShufflePicks();
    }
    _requeue(pending);
    _queueFirstInPicks();
  }

  List<Track> _pendingUserQueue({String? except}) => [
        for (final id in _userQueue)
          if (id != except)
            for (final t in _tracks)
              if (t.id == id) t,
      ];

  /// Puts [pending] back right after the current track, in order. Skipped
  /// when they're already there (the usual case: advancing one track).
  void _requeue(List<Track> pending) {
    _userQueue.clear();
    if (pending.isEmpty) return;
    final inPlace = _currentIndex + pending.length < _tracks.length &&
        [
          for (var k = 0; k < pending.length; k++)
            _tracks[_currentIndex + 1 + k].id == pending[k].id
        ].every((same) => same);
    if (inPlace) {
      _userQueue.addAll(pending.map((t) => t.id));
    } else {
      enqueue(pending);
    }
  }

  /// Marks the track that just became current as played from the queue.
  void _consumeCurrent() {
    final playing = current;
    if (playing != null) _userQueue.remove(playing.id);
  }

  /// Replaces the track with the same id (e.g. refreshed preview URL).
  void replaceTrack(Track updated) {
    for (var i = 0; i < _tracks.length; i++) {
      if (_tracks[i].id == updated.id) _tracks[i] = updated;
    }
  }

  // --- Modes ---

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _forgetShufflePicks();
  }

  void setRepeatMode(PlaybackRepeatMode mode) {
    _repeatMode = mode;
  }

  PlaybackRepeatMode cycleRepeatMode() {
    setRepeatMode(switch (_repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    });
    return _repeatMode;
  }

  bool get isAtEnd => _currentIndex == _tracks.length - 1;

  // --- Navigation ---

  /// Upcoming index without moving. While shuffling, picks and memoizes it.
  int? peekNext() {
    if (_tracks.isEmpty || _currentIndex < 0) return null;

    if (_isShuffle && _tracks.length > 1) {
      if (!_isValid(_nextShuffleIndex) || _nextShuffleIndex == _currentIndex) {
        _nextShuffleIndex = _userQueuedNext() ?? pickSmartNext();
      }
      return _nextShuffleIndex;
    }

    if (_currentIndex + 1 < _tracks.length) return _currentIndex + 1;
    if (_repeatMode == PlaybackRepeatMode.all) return 0;
    if (_repeatMode == PlaybackRepeatMode.one) return _currentIndex;
    return null;
  }

  /// The next [count] indices in play order, without moving: the list order
  /// (wrapping with repeat-all), or memoized shuffle picks that [next] will
  /// then follow. Empty with repeat-one.
  List<int> peekUpcoming(int count) {
    if (_repeatMode == PlaybackRepeatMode.one) return const [];
    final first = peekNext();
    if (first == null || first == _currentIndex) return const [];

    if (!_isShuffle || _tracks.length <= 2) {
      final out = <int>[];
      var i = first;
      while (out.length < count && i != _currentIndex) {
        out.add(i);
        i++;
        if (i >= _tracks.length) {
          if (_repeatMode != PlaybackRepeatMode.all) break;
          i = 0;
        }
      }
      return out;
    }

    return _shufflePicks(count);
  }

  /// The next [count] shuffle picks, making (and memoizing) the missing
  /// ones. Each pick avoids the artists and albums of the ones before it,
  /// as if they had already played.
  List<int> _shufflePicks(int count) {
    final first = peekNext();
    if (first == null || first == _currentIndex) return const [];
    final picks = [first, ..._shuffleLookahead];
    final artists = [..._artistHistory, for (final i in picks) _tracks[i].artistId];
    final albums = [..._albumHistory, for (final i in picks) _tracks[i].albumId];
    List<String> recent(List<String> l) => l.length > _shuffleHistorySize
        ? l.sublist(l.length - _shuffleHistorySize)
        : l;
    while (picks.length < count && picks.length < _tracks.length - 1) {
      final taken = {_currentIndex, ...picks};
      int? pick;
      for (final id in _userQueue) {
        final i = _tracks.indexWhere((t) => t.id == id);
        if (i != -1 && !taken.contains(i)) {
          pick = i;
          break;
        }
      }
      pick ??= pickSmartNext(
          exclude: taken, artists: recent(artists), albums: recent(albums));
      if (taken.contains(pick)) break;
      picks.add(pick);
      _shuffleLookahead.add(pick);
      artists.add(_tracks[pick].artistId);
      albums.add(_tracks[pick].albumId);
    }
    return picks.take(count).toList();
  }

  /// Up to [max] upcoming indices in the order they will play, for showing
  /// the queue: the rest of the list, or the shuffle picks (made ahead as
  /// needed, so [next] follows them). Repeat modes don't change it.
  List<int> upcoming(int max) {
    if (_tracks.isEmpty || _currentIndex < 0 || max <= 0) return const [];
    if (!_isShuffle) {
      return [
        for (var i = _currentIndex + 1;
            i < _tracks.length && i <= _currentIndex + max;
            i++)
          i
      ];
    }
    if (_tracks.length <= 2) {
      return [
        for (var i = 0; i < _tracks.length; i++)
          if (i != _currentIndex) i
      ];
    }
    return _shufflePicks(max);
  }

  /// How many upcoming tracks there are in all (shuffle: every other one).
  int get upcomingCount {
    if (_tracks.isEmpty || _currentIndex < 0) return 0;
    return _isShuffle ? _tracks.length - 1 : _tracks.length - 1 - _currentIndex;
  }

  /// Indices already played, oldest first: the list before the current
  /// track, or the shuffle history.
  List<int> played() {
    if (_currentIndex < 0) return const [];
    if (!_isShuffle) return [for (var i = 0; i < _currentIndex; i++) i];
    final seen = <int>{_currentIndex};
    final out = <int>[];
    for (final i in _history.reversed) {
      if (_isValid(i) && seen.add(i)) out.add(i);
    }
    return out.reversed.toList();
  }

  /// Moves to the next track ("next" button, or end of track with repeat).
  QueueStep next({required bool online, required bool Function(Track) canPlay}) {
    if (_tracks.isEmpty) return QueueStep.unavailable;
    if (!online && !_tracks.any(canPlay)) return QueueStep.unavailable;

    if (_isShuffle && _tracks.length > 1) {
      final preset = _isValid(_nextShuffleIndex) &&
              _nextShuffleIndex != _currentIndex
          ? _nextShuffleIndex
          : null;
      int target;
      if (!online) {
        if (preset != null && canPlay(_tracks[preset])) {
          target = preset;
        } else {
          final cached = [
            for (var i = 0; i < _tracks.length; i++)
              if (i != _currentIndex && canPlay(_tracks[i])) i
          ];
          if (cached.isEmpty) return QueueStep.unavailable;
          target = cached[_rng.nextInt(cached.length)];
        }
      } else {
        target = preset ?? _userQueuedNext() ?? pickSmartNext();
      }
      _pushHistory(_currentIndex);
      _currentIndex = target;
      if (target == preset) {
        _advanceShufflePick();
      } else {
        _forgetShufflePicks();
      }
    } else if (!online) {
      final target = _findFrom(1, canPlay);
      if (target != -1) {
        _pushHistory(_currentIndex);
        _currentIndex = target;
      } else if (_tracks.length == 1 && canPlay(_tracks[0])) {
        _currentIndex = 0;
      } else {
        return QueueStep.unavailable;
      }
    } else {
      _pushHistory(_currentIndex);
      _currentIndex = (_currentIndex + 1) % _tracks.length;
    }

    if (_isShuffle) _recordShuffle(_tracks[_currentIndex]);
    _consumeCurrent();
    return QueueStep.play(_currentIndex);
  }

  /// The first track still waiting in the user's queue, if any.
  int? _userQueuedNext() {
    for (final id in _userQueue) {
      final i = _tracks.indexWhere((t) => t.id == id);
      if (i != -1 && i != _currentIndex) return i;
    }
    return null;
  }

  /// Moves to the previous track. [position] is the current playback
  /// position: past 3 s, "previous" restarts the track instead.
  QueueStep previous({
    required Duration position,
    required bool online,
    required bool Function(Track) canPlay,
  }) {
    if (_tracks.isEmpty) return QueueStep.unavailable;
    if (position.inSeconds > 3) return QueueStep.seekToStart;
    if (!online && !_tracks.any(canPlay)) return QueueStep.unavailable;

    if (_isShuffle) {
      while (_history.isNotEmpty) {
        final prev = _history.removeLast();
        if (!_isValid(prev)) {
          if (online) return QueueStep.seekToStart;
          continue;
        }
        if (online || canPlay(_tracks[prev])) {
          _currentIndex = prev;
          return QueueStep.play(prev);
        }
      }
      return QueueStep.seekToStart;
    }

    if (!online) {
      final target = _findFrom(-1, canPlay);
      if (target != -1) {
        _currentIndex = target;
      } else if (_tracks.length == 1 && canPlay(_tracks[0])) {
        _currentIndex = 0;
      } else {
        return QueueStep.unavailable;
      }
      return QueueStep.play(_currentIndex);
    }

    if (_currentIndex <= 0) {
      if (_repeatMode == PlaybackRepeatMode.off) return QueueStep.seekToStart;
      _currentIndex = _tracks.length - 1;
    } else {
      _currentIndex--;
    }
    return QueueStep.play(_currentIndex);
  }

  /// Whether playback should stop when the current track ends with repeat
  /// off (end of the queue, or every track already heard in shuffle).
  bool shouldStopAtEnd() {
    if (_isShuffle) {
      return _history.toSet().length >= _tracks.length - 1 &&
          !_history.contains(_currentIndex);
    }
    return _currentIndex + 1 >= _tracks.length;
  }

  /// Index to crossfade into, moving the queue there, or null when the queue
  /// ends here.
  int? advanceForCrossfade() {
    if (_tracks.isEmpty) return null;
    int target;
    var preset = false;
    if (_isShuffle && _tracks.length > 1) {
      preset = _isValid(_nextShuffleIndex) && _nextShuffleIndex != _currentIndex;
      target = preset
          ? _nextShuffleIndex!
          : _userQueuedNext() ?? pickSmartNext();
    } else if (_currentIndex + 1 < _tracks.length) {
      target = _currentIndex + 1;
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      target = 0;
    } else {
      return null;
    }
    _pushHistory(_currentIndex);
    _currentIndex = target;
    if (_isShuffle) {
      preset ? _advanceShufflePick() : _forgetShufflePicks();
      _recordShuffle(_tracks[target]);
    }
    _consumeCurrent();
    return target;
  }

  int _findFrom(int direction, bool Function(Track) canPlay) {
    for (var step = 1; step < _tracks.length; step++) {
      final idx =
          (_currentIndex + direction * step + _tracks.length) % _tracks.length;
      if (canPlay(_tracks[idx])) return idx;
    }
    return -1;
  }

  void _pushHistory(int index) {
    if (!_isValid(index)) return;
    _history.add(index);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  /// Weighted random pick that avoids artists/albums heard most recently,
  /// and the indices in [exclude] (besides the current one).
  /// Tracks already heard this time round (the history) are left for last,
  /// so shuffle goes through the whole list before repeating.
  int pickSmartNext({
    Set<int> exclude = const {},
    List<String>? artists,
    List<String>? albums,
  }) {
    final artistHistory = artists ?? _artistHistory;
    final albumHistory = albums ?? _albumHistory;
    final open = [
      for (var i = 0; i < _tracks.length; i++)
        if (i != _currentIndex && !exclude.contains(i)) i
    ];
    final heard = _history.toSet();
    final fresh = [
      for (final i in open)
        if (!heard.contains(i)) i
    ];
    final candidates = fresh.isNotEmpty ? fresh : open;
    if (candidates.isEmpty) return _currentIndex;
    if (candidates.length == 1) return candidates.first;

    var best = double.negativeInfinity;
    final scores = <double>[];
    for (final idx in candidates) {
      final track = _tracks[idx];
      var score = _rng.nextDouble();

      final artistPos = artistHistory.lastIndexOf(track.artistId);
      if (artistPos != -1) {
        score -= 3.0 / (artistHistory.length - artistPos);
      }
      final albumPos = albumHistory.lastIndexOf(track.albumId);
      if (albumPos != -1) {
        score -= 1.5 / (albumHistory.length - albumPos);
      }

      scores.add(score);
      if (score > best) best = score;
    }

    final topTier = [
      for (var i = 0; i < candidates.length; i++)
        if (scores[i] >= best - 0.3) candidates[i]
    ];
    return topTier[_rng.nextInt(topTier.length)];
  }

  void _recordShuffle(Track track) {
    _artistHistory.add(track.artistId);
    if (_artistHistory.length > _shuffleHistorySize) _artistHistory.removeAt(0);
    _albumHistory.add(track.albumId);
    if (_albumHistory.length > _shuffleHistorySize) _albumHistory.removeAt(0);
  }

  // --- Editing ---

  void reorder(int oldIndex, int newIndex) {
    if (!_isValid(oldIndex) || !_isValid(newIndex)) return;
    final playing = current;
    final track = _tracks.removeAt(oldIndex);
    _tracks.insert(newIndex, track);
    if (playing != null) {
      _currentIndex = _tracks.indexWhere((t) => t.id == playing.id);
    }
    _forgetShufflePicks();
    _history.clear();
    if (!_isShuffle) {
      // The user's queue is what sits right after the current track: a
      // queued song dragged further down becomes part of the list.
      final run = <String>[];
      for (var i = _currentIndex + 1;
          i < _tracks.length && _userQueue.contains(_tracks[i].id);
          i++) {
        run.add(_tracks[i].id);
      }
      _userQueue
        ..clear()
        ..addAll(run);
    }
  }

  /// Replaces everything after the current track with [upcoming], which must
  /// be a reordering of those same tracks. Already-played tracks stay put.
  void replaceUpcoming(List<Track> upcoming) {
    final head = _tracks.sublist(0, _currentIndex + 1);
    final tail = _tracks.sublist(_currentIndex + 1);
    final ids = tail.map((t) => t.id).toList()..sort();
    final newIds = upcoming.map((t) => t.id).toList()..sort();
    if (ids.length != newIds.length || ids.join('|') != newIds.join('|')) return;
    _tracks = [...head, ...upcoming];
    _forgetShufflePicks();
    _history.clear();
  }

  /// Moves the upcoming track at play-order position [from] to [to], as
  /// listed by [upcoming]. The user's queue is the run of tracks queued by
  /// hand at the front: a track dropped inside it joins it, one dropped
  /// past its end leaves it.
  void moveUpcoming(int from, int to) {
    if (from == to || from < 0 || to < 0) return;
    final order = [for (final i in upcoming(max(from, to) + 1)) _tracks[i].id];
    if (from >= order.length || to >= order.length) return;
    final id = order[from];
    final wasQueued = _userQueue.contains(id);
    final othersQueued = order.where((o) => o != id && _userQueue.contains(o)).length;

    if (!_isShuffle) {
      final a = _currentIndex + 1 + from;
      final b = _currentIndex + 1 + to;
      final track = _tracks.removeAt(a);
      _tracks.insert(b, track);
      for (var i = 0; i < _history.length; i++) {
        _history[i] = _shifted(_history[i], a, b);
      }
    } else {
      order
        ..removeAt(from)
        ..insert(to, id);
      _setPicks(order);
    }

    final joins = to < othersQueued || (to == othersQueued && wasQueued);
    _userQueue.remove(id);
    if (joins) _userQueue.insert(min(to, _userQueue.length), id);
    if (!_isShuffle) {
      // Keep the user's queue in the order it now sits in the list.
      final pos = {for (var i = 0; i < _tracks.length; i++) _tracks[i].id: i};
      _userQueue.sort((x, y) => (pos[x] ?? 0).compareTo(pos[y] ?? 0));
    }
  }

  QueueSnapshot snapshot() => QueueSnapshot._(
        List.of(_tracks),
        [for (final i in _history) if (_isValid(i)) _tracks[i].id],
        List.of(_userQueue),
        _pickIds(),
        _isShuffle,
      );

  /// Puts the queue back as in [s], keeping the track playing now. Returns
  /// false when that track isn't in [s] (nothing to go back to).
  bool restoreSnapshot(QueueSnapshot s) {
    final playing = current;
    if (playing == null) return false;
    final idx = s.tracks.indexWhere((t) => t.id == playing.id);
    if (idx == -1) return false;
    _tracks = List.of(s.tracks);
    _currentIndex = idx;
    int indexOf(String id) => _tracks.indexWhere((t) => t.id == id);
    _history
      ..clear()
      ..addAll([
        for (final id in s.history)
          if (indexOf(id) case final i when i != -1) i
      ]);
    _userQueue
      ..clear()
      ..addAll(s.userQueue.where((id) => id != playing.id && indexOf(id) != -1));
    if (s.shuffle == _isShuffle) {
      _setPicks(s.shufflePicks);
    } else {
      _forgetShufflePicks();
    }
    return true;
  }

  /// Inserts right after the current track, ahead of the user's queue
  /// ("play next"); a track already elsewhere in the queue moves there.
  /// [userQueued] false is for app-picked tracks (running mode) that
  /// shouldn't show as queued by hand. Returns false for the current track.
  bool insertNext(Track track, {bool userQueued = true}) {
    if (track.id == current?.id) return false;
    _detach(track.id);
    _insertAt(min(_currentIndex + 1, _tracks.length), track);
    if (userQueued) _userQueue.insert(0, track.id);
    // Shuffle keeps the order already made ahead, with this one first.
    _queueFirstInPicks(first: userQueued ? null : track.id);
    return true;
  }

  /// Adds [tracks] to the user's queue: after the current track and what
  /// was queued before, ahead of the rest of the album or playlist. A track
  /// already elsewhere in the queue moves up. Returns how many were queued.
  int enqueue(Iterable<Track> tracks) {
    var added = 0;
    for (final t in tracks) {
      if (t.id == current?.id) continue;
      _detach(t.id);
      var pos = _currentIndex + 1;
      while (pos < _tracks.length && _userQueue.contains(_tracks[pos].id)) {
        pos++;
      }
      _insertAt(pos, t);
      _userQueue.add(t.id);
      added++;
    }
    if (added > 0) _queueFirstInPicks();
    return added;
  }

  /// Takes the track with [id] out of the queue (and the user's queue).
  void _detach(String id) {
    final idx = _tracks.indexWhere((t) => t.id == id);
    if (idx != -1 && idx != _currentIndex) removeAt(idx);
  }

  void _insertAt(int pos, Track track) {
    _tracks.insert(pos, track);
    if (_currentIndex >= pos) _currentIndex++;
    if (_nextShuffleIndex != null && _nextShuffleIndex! >= pos) {
      _nextShuffleIndex = _nextShuffleIndex! + 1;
    }
    for (var i = 0; i < _shuffleLookahead.length; i++) {
      if (_shuffleLookahead[i] >= pos) _shuffleLookahead[i]++;
    }
    for (var i = 0; i < _history.length; i++) {
      if (_history[i] >= pos) _history[i]++;
    }
  }

  /// Appends tracks not already queued, at the very end (radio top-ups).
  /// Returns how many were added.
  int append(Iterable<Track> tracks) {
    final existing = _tracks.map((t) => t.id).toSet();
    var added = 0;
    for (final t in tracks) {
      if (existing.add(t.id)) {
        _tracks.add(t);
        added++;
      }
    }
    return added;
  }

  /// Removes the track at [index]. Returns whether it was the current one.
  bool removeAt(int index) {
    if (!_isValid(index)) return false;
    final wasCurrent = index == _currentIndex;
    final playing = current;
    _userQueue.remove(_tracks[index].id);
    _tracks.removeAt(index);

    if (_nextShuffleIndex == index) {
      _nextShuffleIndex = null;
    } else if (_nextShuffleIndex != null && _nextShuffleIndex! > index) {
      _nextShuffleIndex = _nextShuffleIndex! - 1;
    }
    _shuffleLookahead
      ..removeWhere((i) => i == index)
      ..setAll(0, [for (final i in _shuffleLookahead) i > index ? i - 1 : i]);
    if (_nextShuffleIndex == null) _advanceShufflePick();
    _history.removeWhere((i) => i == index);
    for (var i = 0; i < _history.length; i++) {
      if (_history[i] > index) _history[i]--;
    }

    if (_tracks.isEmpty) {
      _currentIndex = -1;
    } else if (wasCurrent) {
      _currentIndex = index >= _tracks.length ? 0 : index;
    } else if (playing != null) {
      _currentIndex = _tracks.indexWhere((t) => t.id == playing.id);
    }
    return wasCurrent;
  }

  /// Drops the first [count] already-played tracks (endless radio queues).
  void dropBefore(int count) {
    if (count <= 0 || count > _currentIndex) return;
    _tracks.removeRange(0, count);
    _currentIndex -= count;
    _history
      ..removeWhere((i) => i < count)
      ..setAll(0, [for (final i in _history) i - count]);
    final next = _nextShuffleIndex;
    if (next != null) _nextShuffleIndex = next >= count ? next - count : null;
    _shuffleLookahead.clear();
  }

  /// Keeps only [keep] (the playing track), or empties the queue.
  void clear({Track? keep}) {
    _forgetShufflePicks();
    _history.clear();
    _userQueue.clear();
    if (keep != null) {
      _tracks = [keep];
      _currentIndex = 0;
    } else {
      _tracks = [];
      _currentIndex = -1;
    }
  }

  /// Forgets the memoized shuffle pick and the history (playback stopped).
  void resetNavigation() {
    _forgetShufflePicks();
    _history.clear();
  }
}
