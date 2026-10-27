part of 'audio_provider.dart';

mixin _SleepTimerMixin on _AudioProviderBase {
  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  Duration? get sleepTimerRemaining {
    if (_sleepTimerDeadline != null) {
      final diff = _sleepTimerDeadline!.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return _sleepTimerRemaining;
  }

  bool get isSleepTimerActive =>
      _sleepTimerDeadline != null ||
      _sleepTimerRemaining != null ||
      _stopAfterCurrentTrack;

  int? get sleepTimerOriginalMinutes => _sleepTimerOriginalMinutes;

  @visibleForTesting
  DateTime? get sleepTimerDeadline => _sleepTimerDeadline;

  @visibleForTesting
  void setSleepTimerDeadlineForTesting(DateTime? deadline) {
    _sleepTimerDeadline = deadline;
  }

  // ---------------------------------------------------------------------------
  // Timer control
  // ---------------------------------------------------------------------------

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (duration == null) {
      _sleepTimerDeadline = null;
      _sleepTimerRemaining = null;
      _stopAfterCurrentTrack = false;
      _sleepTimerOriginalMinutes = null;
      notifyListeners();
      return;
    }

    if (duration == Duration.zero) {
      _sleepTimerDeadline = null;
      _stopAfterCurrentTrack = true;
      _sleepTimerRemaining = null;
      _sleepTimerOriginalMinutes = 0;
      notifyListeners();
      return;
    }

    _sleepTimerDeadline = DateTime.now().add(duration);
    _sleepTimerRemaining = duration;
    _stopAfterCurrentTrack = false;
    _sleepTimerOriginalMinutes = duration.inMinutes;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      checkSleepTimer();
    });
  }

  @override
  void checkSleepTimer() {
    if (_sleepTimerDeadline == null) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      return;
    }
    final remaining = _sleepTimerDeadline!.difference(DateTime.now());
    if (remaining.inSeconds <= 0) {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepTimerDeadline = null;
      _sleepTimerRemaining = null;
      _stopAfterCurrentTrack = false;
      _sleepTimerOriginalMinutes = null;
      stop();
    } else {
      _sleepTimerRemaining = remaining;
      notifyListeners();
    }
  }
}
