import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/logger.dart';
import '../../data/datasources/audio_player_service.dart';
import '../../data/datasources/system_volume.dart';

final _log = Log.named('SleepTimer');

/// Stops playback after a set time (or at the end of the song), fading the
/// music out over the last stretch so it doesn't cut off.
///
/// - Previews (played here) fade through the player's master volume, on
///   a curve that sounds even to the ear (squared: linear volume sounds
///   like nothing happens, then a sudden drop).
/// - With Spotify, whose volume another app can't set on a phone, the
///   phone's media volume fades instead, and is put back as it was once
///   playback stopped. If the user moves the volume during the fade, it's
///   theirs: the fade stops touching it.
class SleepTimerController {
  final AudioPlayerService _service;
  final VoidCallback _onStateChanged;
  final VoidCallback _onStop;
  final bool Function() _fullSongPlaying;
  final bool Function() _isPlaying;
  final SystemVolumeSource _systemVolume;

  Timer? _timer;
  Timer? _fadeTicker;
  DateTime? _deadline;
  Duration? _remaining;
  Duration _fade = maxFade;
  bool stopAfterCurrentTrack = false;
  int? originalMinutes;

  /// The longest fade-out; short timers fade over their last third.
  static const Duration maxFade = Duration(seconds: 60);

  /// How long after stopping the media volume goes back: Spotify needs a
  /// moment to actually pause.
  @visibleForTesting
  static Duration restoreDelay = const Duration(seconds: 2);

  // Media volume fade (Spotify): where it started, what was last set, and
  // whether the user took the volume over.
  int? _systemStart;
  int? _systemLast;
  bool _userTookVolume = false;
  // Volume still to put back, once playback has really stopped.
  int? _pendingRestore;

  VoidCallback? onFinished;

  SleepTimerController({
    required AudioPlayerService service,
    required VoidCallback onStateChanged,
    required VoidCallback onStop,
    bool Function()? fullSongPlaying,
    bool Function()? isPlaying,
    SystemVolumeSource? systemVolume,
  })  : _service = service,
        _onStateChanged = onStateChanged,
        _onStop = onStop,
        _fullSongPlaying = fullSongPlaying ?? (() => false),
        _isPlaying = isPlaying ?? (() => false),
        _systemVolume = systemVolume ?? SystemVolume();

  Duration? get remaining {
    if (_deadline != null) {
      final diff = _deadline!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return _remaining;
  }

  bool get isActive =>
      _deadline != null || _remaining != null || stopAfterCurrentTrack;

  /// Whether the music is being faded out now.
  bool get isFading => _fadeTicker != null;

  @visibleForTesting
  DateTime? get deadline => _deadline;

  @visibleForTesting
  void setDeadlineForTesting(DateTime? d) => _deadline = d;

  /// How long the fade lasts for a timer of [total].
  static Duration fadeFor(Duration total) {
    final third = total ~/ 3;
    return third < maxFade ? third : maxFade;
  }

  void set(Duration? duration) {
    _timer?.cancel();
    _timer = null;
    _endFade(restore: true);

    if (duration == null) {
      _deadline = null;
      _remaining = null;
      stopAfterCurrentTrack = false;
      originalMinutes = null;
      _onStateChanged();
      return;
    }

    if (duration == Duration.zero) {
      _deadline = null;
      stopAfterCurrentTrack = true;
      _remaining = null;
      originalMinutes = 0;
      _onStateChanged();
      return;
    }

    _deadline = DateTime.now().add(duration);
    _remaining = duration;
    _fade = fadeFor(duration);
    stopAfterCurrentTrack = false;
    originalMinutes = duration.inMinutes;
    _onStateChanged();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => check());
  }

  void check() {
    if (_deadline == null) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final rem = _deadline!.difference(DateTime.now());
    if (rem.inMilliseconds <= 0) {
      _finish();
    } else {
      _remaining = rem;
      if (rem <= _fade && _fadeTicker == null && _isPlaying()) _startFade();
      _onStateChanged();
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _remaining = null;
    stopAfterCurrentTrack = false;
    originalMinutes = null;
    _endFade(restore: false);
    _onStop();
    onFinished?.call();
    _restoreAfterStop();
  }

  bool handleTrackEnd() {
    if (!stopAfterCurrentTrack) return false;
    stopAfterCurrentTrack = false;
    _deadline = null;
    _remaining = null;
    _onStop();
    onFinished?.call();
    return true;
  }

  void _startFade() {
    _fadeTicker = Timer.periodic(const Duration(milliseconds: 250), (_) => _fadeStep());
    unawaited(_fadeStep());
  }

  // The step running now, if any: steps never overlap, or a slow volume
  // read would look like the user moving it.
  Future<void>? _stepping;

  @visibleForTesting
  Future<void> fadeStep() => _fadeStep();

  Future<void> _fadeStep() =>
      _stepping ??= _doFadeStep().whenComplete(() => _stepping = null);

  Future<void> _doFadeStep() async {
    final deadline = _deadline;
    if (deadline == null) return;
    final rem = deadline.difference(DateTime.now());
    final t = (rem.inMilliseconds / _fade.inMilliseconds).clamp(0.0, 1.0);

    if (!_fullSongPlaying()) {
      _service.masterVolume = t * t;
      return;
    }
    // Spotify: the phone's media volume.
    if (_userTookVolume) return;
    final now = await _systemVolume.read();
    if (now == null || _fadeTicker == null) return;
    if (_systemStart == null) {
      _systemStart = now.current;
      _systemLast = now.current;
    } else if (now.current != _systemLast) {
      _log.info('volume changed by hand during the fade: leaving it');
      _userTookVolume = true;
      return;
    }
    // Android's steps already follow loudness, so they go down evenly.
    final target = (_systemStart! * t).ceil();
    if (target != _systemLast) {
      _systemLast = target;
      await _systemVolume.set(target);
    }
  }

  /// Stops fading. [restore]: put the volume back now (the timer was
  /// cancelled or changed, playback goes on).
  void _endFade({required bool restore}) {
    _fadeTicker?.cancel();
    _fadeTicker = null;
    final start = _systemStart;
    final took = _userTookVolume;
    _systemStart = null;
    _systemLast = null;
    _userTookVolume = false;
    if (restore) {
      _service.masterVolume = 1.0;
      if (start != null && !took) unawaited(_systemVolume.set(start));
    } else if (start != null && !took) {
      _pendingRestore = start;
    }
  }

  /// After the timer stopped playback: the player's volume goes back at
  /// once (nothing plays), the media volume once Spotify has paused. If it
  /// still plays then, the volume stays down (better than waking anyone)
  /// and goes back the next time playback is started by hand.
  void _restoreAfterStop() {
    _service.masterVolume = 1.0;
    if (_pendingRestore == null) return;
    unawaited(Future<void>.delayed(restoreDelay, () async {
      final volume = _pendingRestore;
      if (volume == null) return;
      if (_isPlaying()) {
        _log.warning('still playing after the sleep timer: volume left down');
        return;
      }
      _pendingRestore = null;
      await _systemVolume.set(volume);
    }));
  }

  /// Puts back a media volume the timer left down. Called when the user
  /// starts playback.
  Future<void> restoreVolume() async {
    final volume = _pendingRestore;
    if (volume == null) return;
    _pendingRestore = null;
    await _systemVolume.set(math.max(volume, 0));
  }

  void dispose() {
    _timer?.cancel();
    _fadeTicker?.cancel();
  }
}
