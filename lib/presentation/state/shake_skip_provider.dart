import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../data/datasources/motion_sensor.dart';
import '../../domain/logic/shake_detector.dart';
import 'audio_provider.dart';
import 'run_provider.dart';


final _log = Log.named('Shake');

/// Shake the phone to skip to the next song. Off by default.
///
/// The sensor only runs while the app is on screen with a song loaded, and
/// never during running mode, where the phone shakes with every step.
class ShakeSkipProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefKey = 'shake_to_skip';

  final MotionSource _sensor;
  final ShakeDetector _detector = ShakeDetector();
  AudioProvider? _audio;
  RunProvider? _run;
  bool _enabled = false;
  bool _foreground = true;
  StreamSubscription<MotionSample>? _sub;

  ShakeSkipProvider({MotionSource? sensor}) : _sensor = sensor ?? phoneAccelerometer {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  bool get enabled => _enabled;
  bool get listening => _sub != null;

  void attach(AudioProvider audio, RunProvider run) {
    if (!identical(audio, _audio)) {
      _audio?.removeListener(_evaluate);
      _audio = audio..addListener(_evaluate);
    }
    if (!identical(run, _run)) {
      _run?.removeListener(_evaluate);
      _run = run..addListener(_evaluate);
    }
    _evaluate();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? false;
      _evaluate();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _evaluate();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _evaluate();
  }

  void _evaluate() {
    final want = _enabled &&
        _foreground &&
        _audio?.currentTrack != null &&
        !(_run?.active ?? false);
    if (want && _sub == null) {
      _detector.reset();
      _sub = _sensor().listen(
        (s) {
          if (_detector.add(s.x, s.y, s.z, s.t)) _onShake();
        },
        onError: (Object e) {
          _log.severe('sensor error: $e');
          _sub = null;
        },
        cancelOnError: true,
      );
    } else if (!want && _sub != null) {
      _sub!.cancel();
      _sub = null;
    }
  }

  void _onShake() {
    final audio = _audio;
    if (audio == null || audio.currentTrack == null) return;
    HapticFeedback.mediumImpact();
    unawaited(audio.next());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _audio?.removeListener(_evaluate);
    _run?.removeListener(_evaluate);
    super.dispose();
  }
}
