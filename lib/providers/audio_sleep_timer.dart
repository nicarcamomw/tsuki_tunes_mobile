import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/audio_player_service.dart';

class SleepTimerController {
  final AudioPlayerService _service;
  final VoidCallback _onStateChanged;
  final VoidCallback _onStop;

  Timer? _timer;
  DateTime? _deadline;
  Duration? _remaining;
  bool stopAfterCurrentTrack = false;
  int? originalMinutes;
  bool _fadeApplied = false;
  static const int _fadeSeconds = 20;

  VoidCallback? onFinished;

  SleepTimerController({
    required AudioPlayerService service,
    required VoidCallback onStateChanged,
    required VoidCallback onStop,
  })  : _service = service,
        _onStateChanged = onStateChanged,
        _onStop = onStop;

  Duration? get remaining {
    if (_deadline != null) {
      final diff = _deadline!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return _remaining;
  }

  bool get isActive =>
      _deadline != null || _remaining != null || stopAfterCurrentTrack;

  @visibleForTesting
  DateTime? get deadline => _deadline;

  @visibleForTesting
  void setDeadlineForTesting(DateTime? d) => _deadline = d;

  void set(Duration? duration) {
    _timer?.cancel();
    _timer = null;
    _restoreFade();

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
    if (rem.inSeconds <= 0) {
      _timer?.cancel();
      _timer = null;
      _deadline = null;
      _remaining = null;
      stopAfterCurrentTrack = false;
      originalMinutes = null;
      _fadeApplied = false;
      _onStop();
      onFinished?.call();
    } else {
      _remaining = rem;
      _applyFade(rem);
      _onStateChanged();
    }
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

  void _applyFade(Duration rem, {bool spotifyActive = false}) {
    if (spotifyActive) return;
    if (rem.inSeconds > _fadeSeconds) return;
    _fadeApplied = true;
    final level = rem.inMilliseconds / (_fadeSeconds * 1000);
    unawaited(_service.setVolume(level.clamp(0.0, 1.0)));
  }

  void _restoreFade() {
    if (!_fadeApplied) return;
    _fadeApplied = false;
    unawaited(_service.setVolume(1.0));
  }

  void dispose() {
    _timer?.cancel();
  }
}
