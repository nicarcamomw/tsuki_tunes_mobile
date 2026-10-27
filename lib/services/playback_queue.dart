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

  // Indices played before the current one (shuffle "previous").
  final List<int> _history = [];
  static const int _maxHistory = 50;

  // Recently played artists/albums, to avoid repeats when shuffling.
  final List<String> _artistHistory = [];
  final List<String> _albumHistory = [];
  static const int _shuffleHistorySize = 5;

  List<Track> get tracks => _tracks;
  int get currentIndex => _currentIndex;
  bool get isEmpty => _tracks.isEmpty;
  int get length => _tracks.length;
  bool get isShuffle => _isShuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  int? get nextShuffleIndex => _nextShuffleIndex;
  List<int> get history => List.unmodifiable(_history);

  Track? get current => _currentIndex >= 0 && _currentIndex < _tracks.length
      ? _tracks[_currentIndex]
      : null;

  bool _isValid(int? i) => i != null && i >= 0 && i < _tracks.length;

  // --- Building the queue ---

  /// Restores a persisted queue without touching history.
  void restore(List<Track> tracks, int index) {
    _tracks = List.of(tracks);
    _currentIndex = _isValid(index) ? index : (tracks.isEmpty ? -1 : 0);
  }

  /// Makes [track] current, replacing the queue with [newQueue] if given,
  /// otherwise selecting it in (or appending it to) the current queue.
  void select(Track track, {List<Track>? newQueue}) {
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
    _nextShuffleIndex = null;
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
    _nextShuffleIndex = null;
  }

  void setRepeatMode(PlaybackRepeatMode mode) {
    _repeatMode = mode;
    _nextShuffleIndex = null;
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
        _nextShuffleIndex = pickSmartNext();
      }
      return _nextShuffleIndex;
    }

    if (_currentIndex + 1 < _tracks.length) return _currentIndex + 1;
    if (_repeatMode == PlaybackRepeatMode.all) return 0;
    if (_repeatMode == PlaybackRepeatMode.one) return _currentIndex;
    return null;
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
        target = preset ?? pickSmartNext();
      }
      _pushHistory(_currentIndex);
      _currentIndex = target;
      _nextShuffleIndex = null;
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
    return QueueStep.play(_currentIndex);
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
    if (_isShuffle && _tracks.length > 1) {
      target = _isValid(_nextShuffleIndex) && _nextShuffleIndex != _currentIndex
          ? _nextShuffleIndex!
          : pickSmartNext();
      _nextShuffleIndex = null;
    } else if (_currentIndex + 1 < _tracks.length) {
      target = _currentIndex + 1;
    } else if (_repeatMode == PlaybackRepeatMode.all) {
      target = 0;
    } else {
      return null;
    }
    _pushHistory(_currentIndex);
    _currentIndex = target;
    if (_isShuffle) _recordShuffle(_tracks[target]);
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

  /// Weighted random pick that avoids artists/albums heard most recently.
  int pickSmartNext() {
    final candidates = [
      for (var i = 0; i < _tracks.length; i++)
        if (i != _currentIndex) i
    ];
    if (candidates.isEmpty) return _currentIndex;
    if (candidates.length == 1) return candidates.first;

    var best = double.negativeInfinity;
    final scores = <double>[];
    for (final idx in candidates) {
      final track = _tracks[idx];
      var score = _rng.nextDouble();

      final artistPos = _artistHistory.lastIndexOf(track.artistId);
      if (artistPos != -1) {
        score -= 3.0 / (_artistHistory.length - artistPos);
      }
      final albumPos = _albumHistory.lastIndexOf(track.albumId);
      if (albumPos != -1) {
        score -= 1.5 / (_albumHistory.length - albumPos);
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
    _nextShuffleIndex = null;
    _history.clear();
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
    _nextShuffleIndex = null;
    _history.clear();
  }

  /// Inserts right after the current track. Returns false if already queued.
  bool insertNext(Track track) {
    if (_tracks.any((t) => t.id == track.id)) return false;
    final pos = min(_currentIndex + 1, _tracks.length);
    _tracks.insert(pos, track);
    if (_nextShuffleIndex != null && _nextShuffleIndex! >= pos) {
      _nextShuffleIndex = _nextShuffleIndex! + 1;
    }
    for (var i = 0; i < _history.length; i++) {
      if (_history[i] >= pos) _history[i]++;
    }
    return true;
  }

  /// Appends tracks not already queued. Returns how many were added.
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
    _tracks.removeAt(index);

    if (_nextShuffleIndex == index) {
      _nextShuffleIndex = null;
    } else if (_nextShuffleIndex != null && _nextShuffleIndex! > index) {
      _nextShuffleIndex = _nextShuffleIndex! - 1;
    }
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
  }

  /// Keeps only [keep] (the playing track), or empties the queue.
  void clear({Track? keep}) {
    _nextShuffleIndex = null;
    _history.clear();
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
    _nextShuffleIndex = null;
    _history.clear();
  }
}
