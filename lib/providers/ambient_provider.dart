import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ambient_sound_generator.dart';

export '../services/ambient_sound_generator.dart' show AmbientSound;

/// Ambient sound layers (rain, waves...) that play on top of whatever music
/// is playing, including Spotify.
///
/// The players never take audio focus, otherwise starting the rain would
/// pause Spotify.
class AmbientProvider extends ChangeNotifier {
  static const _afterTimerKey = 'ambient_after_timer_minutes';
  static const _volumesKey = 'ambient_last_volumes';
  static const _cacheVersion = 'v1';
  static const double defaultVolume = 0.6;

  /// Minutes the ambient keeps playing after the sleep timer stops the music.
  /// 0 stops it together with the music, -1 never stops it.
  static const List<int> afterTimerOptions = [0, 15, 30, 60, -1];

  final Map<AmbientSound, double> _volumes = {};
  final Map<AmbientSound, AudioPlayer> _players = {};
  final Set<AmbientSound> _loading = {};
  final Map<AmbientSound, double> _lastVolumes = {};
  double _master = 1.0;
  bool _paused = false;
  int _afterTimerMinutes = 0;
  DateTime? _stopDeadline;
  Timer? _stopTimer;
  Timer? _fadeTimer;
  StreamSubscription? _noisySub;

  /// Pushes ambient-only state to the system media notification, so Android
  /// keeps the app alive when only the rain is playing with the screen off.
  void Function({required String? title, required bool playing})? onMediaStateChanged;
  final String Function(AmbientSound sound)? labelFor;

  AmbientProvider({this.labelFor}) {
    _restore();
    _listenNoisy();
  }

  bool get isActive => _volumes.isNotEmpty;
  bool get isPlaying => isActive && !_paused;
  bool isOn(AmbientSound s) => _volumes.containsKey(s);
  bool isLoading(AmbientSound s) => _loading.contains(s);
  double volumeOf(AmbientSound s) =>
      _volumes[s] ?? _lastVolumes[s] ?? defaultVolume;
  Set<AmbientSound> get activeSounds => _volumes.keys.toSet();
  int get afterTimerMinutes => _afterTimerMinutes;

  /// When a post-sleep-timer countdown is running, the time it has left.
  Duration? get stopRemaining {
    final d = _stopDeadline;
    if (d == null) return null;
    final r = d.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _afterTimerMinutes = prefs.getInt(_afterTimerKey) ?? 0;
      for (final entry in prefs.getStringList(_volumesKey) ?? const <String>[]) {
        final parts = entry.split(':');
        if (parts.length != 2) continue;
        final sound = AmbientSound.values.where((s) => s.name == parts[0]);
        final vol = double.tryParse(parts[1]);
        if (sound.isNotEmpty && vol != null) _lastVolumes[sound.first] = vol;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Ambient] restore error: $e');
    }
  }

  Future<void> _persistVolumes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_volumesKey,
          _lastVolumes.entries.map((e) => '${e.key.name}:${e.value}').toList());
    } catch (_) {}
  }

  void _listenNoisy() {
    // Headphones unplugged: don't blast rain out of the speaker at night.
    AudioSession.instance.then((session) {
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        if (isPlaying) pauseAll();
      });
    }).catchError((e) {
      debugPrint('[Ambient] audio session error: $e');
    });
  }

  Future<void> setAfterTimerMinutes(int minutes) async {
    _afterTimerMinutes = minutes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_afterTimerKey, minutes);
    } catch (_) {}
  }

  Future<void> toggle(AmbientSound sound) async {
    if (isOn(sound)) {
      await _turnOff(sound);
    } else {
      await _turnOn(sound);
    }
  }

  Future<void> _turnOn(AmbientSound sound) async {
    if (_loading.contains(sound)) return;
    _cancelFade();
    _master = 1.0;
    _loading.add(sound);
    notifyListeners();
    try {
      final path = await _ensureFile(sound);
      final player = _players[sound] ??= AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      await player.setFilePath(path);
      await player.setLoopMode(LoopMode.one);
      _volumes[sound] = volumeOf(sound);
      // Re-apply every layer: a cancelled fade may have left them quieter.
      for (final e in _volumes.entries) {
        await _players[e.key]?.setVolume(_gain(e.value));
      }
      if (_paused) {
        _paused = false;
        for (final s in _volumes.keys) {
          if (s != sound) unawaited(_players[s]?.play());
        }
      }
      unawaited(player.play());
    } catch (e) {
      debugPrint('[Ambient] could not start ${sound.name}: $e');
      _volumes.remove(sound);
    } finally {
      _loading.remove(sound);
      _changed();
    }
  }

  Future<void> _turnOff(AmbientSound sound) async {
    _volumes.remove(sound);
    final player = _players.remove(sound);
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
    if (_volumes.isEmpty) _clearStopTimer();
    _changed();
  }

  Future<void> setVolume(AmbientSound sound, double volume) async {
    if (!isOn(sound)) return;
    _volumes[sound] = volume;
    _lastVolumes[sound] = volume;
    notifyListeners();
    await _players[sound]?.setVolume(_gain(volume));
  }

  Future<void> commitVolumes() => _persistVolumes();

  Future<void> pauseAll() async {
    if (!isActive) return;
    _cancelFade();
    _paused = true;
    _changed();
    for (final p in _players.values) {
      await p.pause();
    }
  }

  Future<void> resumeAll() async {
    if (!isActive) return;
    _cancelFade();
    _master = 1.0;
    _paused = false;
    for (final e in _volumes.entries) {
      await _players[e.key]?.setVolume(_gain(e.value));
    }
    _changed();
    for (final p in _players.values) {
      unawaited(p.play());
    }
  }

  Future<void> stopAll() async {
    _cancelFade();
    _clearStopTimer();
    _volumes.clear();
    _paused = false;
    _master = 1.0;
    final players = _players.values.toList();
    _players.clear();
    _changed();
    for (final p in players) {
      await p.stop();
      await p.dispose();
    }
  }

  /// Called by the audio provider when the sleep timer stops the music.
  void onSleepTimerFinished() {
    if (!isPlaying) return;
    final minutes = _afterTimerMinutes;
    if (minutes < 0) return;
    if (minutes == 0) {
      fadeOutAndStop();
      return;
    }
    _clearStopTimer();
    _stopDeadline = DateTime.now().add(Duration(minutes: minutes));
    _stopTimer = Timer(Duration(minutes: minutes), () {
      _stopDeadline = null;
      fadeOutAndStop();
    });
    notifyListeners();
  }

  Future<void> fadeOutAndStop({Duration duration = const Duration(seconds: 20)}) async {
    if (!isActive) return;
    _cancelFade();
    const step = Duration(milliseconds: 250);
    final steps = duration.inMilliseconds ~/ step.inMilliseconds;
    var i = 0;
    _fadeTimer = Timer.periodic(step, (t) {
      i++;
      _master = (1 - i / steps).clamp(0.0, 1.0);
      for (final e in _volumes.entries) {
        _players[e.key]?.setVolume(_gain(e.value));
      }
      if (i >= steps) {
        t.cancel();
        _fadeTimer = null;
        stopAll();
      }
    });
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  void _clearStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _stopDeadline = null;
  }

  // Squared so the slider feels linear to the ear.
  double _gain(double v) => (v * v * _master).clamp(0.0, 1.0);

  void _changed() {
    notifyListeners();
    final label = labelFor;
    onMediaStateChanged?.call(
      title: isActive
          ? _volumes.keys.map((s) => label?.call(s) ?? s.name).join(' · ')
          : null,
      playing: isPlaying,
    );
  }

  static Future<String> _ensureFile(AmbientSound sound) async {
    final dir = Directory('${Directory.systemTemp.path}/tsuki_ambient');
    final file = File('${dir.path}/${_cacheVersion}_${sound.name}.wav');
    if (await file.exists() && await file.length() > 44) return file.path;
    await dir.create(recursive: true);
    final bytes = await compute(AmbientSoundGenerator.generateWav, sound);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  void dispose() {
    _cancelFade();
    _clearStopTimer();
    _noisySub?.cancel();
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }
}
