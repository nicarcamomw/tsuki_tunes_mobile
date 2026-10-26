import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/bpm_flow.dart';
import '../services/cadence_detector.dart';
import '../services/deezer_api_service.dart';
import '../services/motion_sensor.dart';
import '../services/pace_matcher.dart';
import '../services/run_catalog.dart';
import 'audio_provider.dart';
import 'library_provider.dart';

enum RunPhase {
  /// Waiting for a steady rhythm before choosing music.
  waiting,
  /// Looking for songs at the pace.
  searching,
  /// Music is following the steps.
  playing,
  /// Nothing found at this pace yet.
  noMatches,
}

/// Running / walking mode: reads the step cadence from the accelerometer
/// and keeps the queue filled with songs at that tempo, nudging their speed
/// so the beat lines up with the steps.
class RunProvider extends ChangeNotifier {
  static const _syncKey = 'run_sync_tempo';
  static const _enabledKey = 'run_mode_enabled';
  static const Duration tick = Duration(milliseconds: 500);
  /// The target follows the cadence only once it moves this much, so small
  /// wobbles don't churn the queue.
  static const double retargetAt = 0.03;
  /// Songs kept lined up after the current one.
  static const int lookahead = 2;
  /// The mode ends by itself after the music has been paused this long.
  static const Duration idleTimeout = Duration(minutes: 10);

  final MotionSource _sensor;
  final RunCatalog Function() _newCatalog;
  final Random _rng;
  DateTime Function() _now;

  AudioProvider? _audio;
  LibraryProvider? _library;

  RunProvider({
    MotionSource? sensor,
    RunCatalog Function()? catalog,
    Random? random,
    @visibleForTesting DateTime Function()? clock,
  })  : _sensor = sensor ?? phoneAccelerometer,
        _newCatalog = catalog ??
            (() => RunCatalog(bpm: BpmService.shared, search: DeezerApiService().searchTracks)),
        _rng = random ?? Random(),
        _now = clock ?? DateTime.now {
    _loadPrefs();
  }

  // --- State ---
  bool _enabled = true;
  bool _active = false;
  RunPhase _phase = RunPhase.waiting;
  bool _sensorAvailable = true;
  CadenceReading _reading = CadenceReading.none;
  double? _target;
  double? _locked;
  bool _syncTempo = true;
  RunCatalog? _catalog;

  DateTime? _startedAt;
  double _steps = 0;
  double _cadenceSum = 0;
  int _cadenceTicks = 0;
  final List<double> _history = [];
  double _historyAcc = 0;
  int _historyN = 0;
  int _songs = 0;

  bool get enabled => _enabled;
  bool get active => _active;
  RunPhase get phase => _phase;
  bool get sensorAvailable => _sensorAvailable;
  CadenceReading get reading => _reading;
  /// Pace the music follows, in steps per minute.
  double? get target => _locked ?? _target;
  bool get isLocked => _locked != null;
  bool get syncTempo => _syncTempo;
  Duration get elapsed => _startedAt == null ? Duration.zero : _now().difference(_startedAt!);
  int get steps => _steps.round();
  double? get averageCadence => _cadenceTicks == 0 ? null : _cadenceSum / _cadenceTicks;
  /// Cadence every 5 seconds of the session (0 while standing).
  List<double> get history => List.unmodifiable(_history);
  int get songs => _songs;
  int get knownSongs => _catalog?.knownCount ?? 0;

  /// Tempo of what is playing, if known.
  double? get currentBpm {
    final t = _audio?.currentTrack;
    return t == null ? null : _catalog?.bpms[t.id] ?? BpmService.shared.cached(t.id);
  }

  /// Speed the current song plays at (1.0 when not synced).
  double get currentRate {
    final bpm = currentBpm;
    final pace = target;
    if (!_active || !_syncTempo || bpm == null || pace == null) return 1.0;
    if (!(_audio?.canChangeTempo ?? false)) return 1.0;
    return PaceMatcher.playbackRate(bpm, pace);
  }

  void attach(AudioProvider audio, LibraryProvider library) {
    _library = library;
    if (identical(_audio, audio)) return;
    _audio?.removeListener(_onAudio);
    _audio = audio;
    if (_active) audio.addListener(_onAudio);
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _syncTempo = prefs.getBool(_syncKey) ?? true;
      _enabled = prefs.getBool(_enabledKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  /// Whether the mode is offered at all (its card on the home screen).
  /// Turning it off ends a running session.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
  }

  Future<void> setSyncTempo(bool value) async {
    _syncTempo = value;
    _applyTempo();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncKey, value);
    } catch (_) {}
  }

  // --- Session ---
  StreamSubscription<MotionSample>? _sub;
  Timer? _timer;
  final CadenceDetector _detector = CadenceDetector();
  final Set<String> _queued = {};
  final Set<String> _played = {};
  String? _currentId;
  DateTime? _idleSince;
  DateTime? _driftSince;
  bool _filling = false;
  bool _refill = false;

  Future<void> start() async {
    if (_active || !_enabled) return;
    final audio = _audio;
    if (audio == null) return;
    _active = true;
    _phase = RunPhase.waiting;
    _reading = CadenceReading.none;
    _target = null;
    _startedAt = _now();
    _steps = 0;
    _cadenceSum = 0;
    _cadenceTicks = 0;
    _history.clear();
    _historyAcc = 0;
    _historyN = 0;
    _songs = 0;
    _queued.clear();
    _played.clear();
    _currentId = audio.currentTrack?.id;
    _idleSince = null;
    _driftSince = null;
    _detector.reset();

    final lib = _library;
    final catalog = _catalog = _newCatalog();
    unawaited(catalog.warmUp(
      favorites: lib?.favoriteTracks ?? const [],
      recent: lib?.recentTracks ?? const [],
      favoriteArtistNames: [...?lib?.favoriteArtists.map((a) => a.name)],
    ));

    final playing = audio.currentTrack;
    if (playing != null) unawaited(catalog.tempoOf(playing).then((_) => _applyTempo()));
    audio.addListener(_onAudio);
    audio.tempoFor = _rateFor;
    _sensorAvailable = true;
    _sub = _sensor().listen(
      (s) => _detector.add(s.x, s.y, s.z, s.t),
      onError: (Object e) {
        debugPrint('[Run] sensor error: $e');
        _sensorAvailable = false;
        _locked ??= 120;
        _onTarget();
        notifyListeners();
      },
      cancelOnError: true,
    );
    _timer = Timer.periodic(tick, (_) => _onTick());
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    _timer?.cancel();
    _timer = null;
    final audio = _audio;
    if (audio != null) {
      audio.removeListener(_onAudio);
      audio.tempoFor = null;
    }
    _catalog = null;
    notifyListeners();
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  /// Holds the music at the current pace (or [bpm]) whatever the steps do.
  void lock([double? bpm]) {
    final v = bpm ?? target;
    if (v == null) return;
    _locked = v.clamp(60.0, 220.0).roundToDouble();
    _onTarget();
    notifyListeners();
  }

  void unlock() {
    if (!_sensorAvailable) return;
    _locked = null;
    _onTarget();
    notifyListeners();
  }

  void nudgeLock(int delta) {
    final v = _locked;
    if (v != null) lock(v + delta);
  }

  double _rateFor(Track track) {
    if (!_syncTempo) return 1.0;
    final pace = target;
    final bpm = _catalog?.bpms[track.id] ?? BpmService.shared.cached(track.id);
    if (pace == null || bpm == null) return 1.0;
    return PaceMatcher.playbackRate(bpm, pace);
  }

  void _onTick() {
    if (!_active) return;
    final r = _detector.update();
    final seconds = tick.inMilliseconds / 1000;
    if (r.spm != null) {
      _steps += r.spm! * seconds / 60;
      _cadenceSum += r.spm!;
      _cadenceTicks++;
    }
    _historyAcc += r.spm ?? 0;
    if (++_historyN * tick.inMilliseconds >= 5000) {
      _history.add(_historyAcc / _historyN);
      if (_history.length > 360) _history.removeAt(0);
      _historyAcc = 0;
      _historyN = 0;
    }

    final changed = r.spm != _reading.spm || r.state != _reading.state;
    _reading = r;
    if (r.spm != null && _locked == null) {
      final t = _target;
      if (t == null || (r.spm! / t - 1).abs() > retargetAt) {
        _target = r.spm!.roundToDouble();
        _onTarget();
      }
    }
    _checkDrift();
    _checkIdle();
    if (changed) notifyListeners();
  }

  /// The pace moved: line up songs for it and re-sync the current one.
  void _onTarget() {
    _applyTempo();
    final pace = target;
    if (pace == null) return;
    final audio = _audio;
    if (audio == null) return;
    // Lined-up songs that no longer fit are replaced.
    final upcoming = audio.upcomingTracks;
    for (var i = upcoming.length - 1; i >= 0; i--) {
      final t = upcoming[i];
      if (!_queued.contains(t.id)) continue;
      final bpm = _catalog?.bpms[t.id];
      if (bpm == null || PaceMatcher.match(bpm, pace).deviation > PaceMatcher.tolerance) {
        _queued.remove(t.id);
        audio.removeFromQueue(audio.currentIndex + 1 + i);
      }
    }
    unawaited(_fill());
  }

  void _applyTempo() => _audio?.refreshTempo();

  void _onAudio() {
    final audio = _audio;
    if (audio == null || !_active) return;
    final id = audio.currentTrack?.id;
    if (id != _currentId) {
      _currentId = id;
      _driftSince = null;
      if (id != null) {
        _played.add(id);
        if (_queued.remove(id)) _songs++;
        // A song picked elsewhere: learn its tempo so it can be synced.
        final track = audio.currentTrack!;
        final catalog = _catalog;
        if (catalog != null && catalog.bpms[id] == null) {
          unawaited(catalog.tempoOf(track).then((_) => _applyTempo()));
        }
      }
      unawaited(_fill());
      notifyListeners();
    }
  }

  /// Keeps [lookahead] songs at the current pace lined up; starts the music
  /// when nothing is playing yet.
  Future<void> _fill() async {
    if (_filling) {
      _refill = true;
      return;
    }
    _filling = true;
    try {
      do {
        _refill = false;
        await _fillOnce();
      } while (_refill && _active);
    } finally {
      _filling = false;
    }
  }

  Future<void> _fillOnce() async {
    final audio = _audio;
    final catalog = _catalog;
    final pace = target;
    if (!_active || audio == null || catalog == null || pace == null) return;

    final startNow = audio.currentTrack == null || (!audio.isPlaying && _songs == 0 && _queued.isEmpty);
    final upcomingOurs = audio.upcomingTracks.where((t) => _queued.contains(t.id)).length;
    final need = (startNow ? 1 : 0) + max(0, lookahead - upcomingOurs);
    if (need == 0) {
      if (_phase != RunPhase.playing) {
        _phase = RunPhase.playing;
        notifyListeners();
      }
      return;
    }

    if (_phase != RunPhase.playing) {
      _phase = RunPhase.searching;
      notifyListeners();
    }

    final picks = <Track>[];
    String? lastArtist = audio.upcomingTracks.isNotEmpty
        ? audio.upcomingTracks.last.artistId
        : audio.currentTrack?.artistId;
    var explored = false;
    while (picks.length < need) {
      final avoid = {..._played, ..._queued, ...picks.map((t) => t.id), ...audio.queue.map((t) => t.id)};
      var t = await catalog.next(pace, avoid: avoid, lastArtistId: lastArtist, random: _rng);
      if (t == null && !explored) {
        explored = true;
        await catalog.explore(pace);
        t = await catalog.next(pace, avoid: avoid, lastArtistId: lastArtist, random: _rng);
      }
      if (t == null) break;
      picks.add(t);
      lastArtist = t.artistId;
    }
    // The pace may have moved while searching; the next fill catches up.
    if (!_active || !identical(catalog, _catalog)) return;

    if (picks.isEmpty) {
      if (_queued.isEmpty && (audio.currentTrack == null || !audio.isPlaying)) {
        _phase = RunPhase.noMatches;
        notifyListeners();
      }
      return;
    }

    if (startNow) {
      final first = picks.removeAt(0);
      _queued.add(first.id);
      if (audio.isShuffle) audio.toggleShuffle();
      if (audio.repeatMode != PlaybackRepeatMode.off) audio.setRepeatMode(PlaybackRepeatMode.off);
      _queued.addAll(picks.map((t) => t.id));
      // Not awaited: the queue is set at once, loading can take a moment.
      unawaited(audio.playTrack(first, newQueue: [first, ...picks]));
    } else {
      // Ours go right after the current song, ahead of anything else that
      // was already queued.
      final pickIds = picks.map((t) => t.id).toSet();
      for (final t in picks) {
        _queued.add(t.id);
        audio.playNext(t);
      }
      final up = audio.upcomingTracks;
      audio.setUpcomingOrder([
        ...up.where((t) => _queued.contains(t.id) && !pickIds.contains(t.id)),
        ...picks,
        ...up.where((t) => !_queued.contains(t.id)),
      ]);
    }
    _phase = RunPhase.playing;
    notifyListeners();
  }

  /// A full-length song far from a pace held for a while is cut short.
  /// (Previews are only 30 seconds, so they always finish.)
  void _checkDrift() {
    final audio = _audio;
    final bpm = currentBpm;
    final pace = target;
    if (audio == null || bpm == null || pace == null || !audio.isPlaying) {
      _driftSince = null;
      return;
    }
    final remaining = audio.duration - audio.position;
    final far = PaceMatcher.match(bpm, pace).deviation > PaceMatcher.driftLimit;
    if (!far || remaining < const Duration(seconds: 30)) {
      _driftSince = null;
      return;
    }
    final since = _driftSince ??= _now();
    if (_now().difference(since) >= PaceMatcher.driftPatience &&
        audio.upcomingTracks.any((t) => _queued.contains(t.id))) {
      _driftSince = null;
      unawaited(audio.next());
    }
  }

  void _checkIdle() {
    final audio = _audio;
    if (audio == null || audio.isPlaying || _phase == RunPhase.searching) {
      _idleSince = null;
      return;
    }
    final since = _idleSince ??= _now();
    if (_now().difference(since) >= idleTimeout) unawaited(stop());
  }

  /// Feeds a reading as if from the sensor (tests).
  @visibleForTesting
  void tickForTesting() => _onTick();

  @visibleForTesting
  set clockForTesting(DateTime Function() clock) => _now = clock;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _audio?.removeListener(_onAudio);
    super.dispose();
  }
}
