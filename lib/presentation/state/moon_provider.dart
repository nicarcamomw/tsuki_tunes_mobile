import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/logic/moon_calculator.dart';

export '../../domain/logic/moon_calculator.dart';

class MoonProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _atmosphereKey = 'moon_atmosphere_enabled';
  static const Duration eclipsePreviewLength = Duration(seconds: 20);

  // Countries that lie mostly south of the equator, where the Moon appears
  // upside down compared to the northern view (waxing lit side on the left).
  static const _southernCountries = {
    'AR', 'AO', 'AU', 'BO', 'BR', 'BW', 'CL', 'FJ', 'ID', 'LS', 'MG', 'MU',
    'MW', 'MZ', 'NA', 'NC', 'NZ', 'PE', 'PF', 'PG', 'PY', 'SZ', 'TZ', 'UY',
    'WS', 'ZA', 'ZM', 'ZW',
  };

  final DateTime Function() _clock;
  final bool southernHemisphere;
  late MoonSnapshot _snapshot;
  LunarEclipse? _eclipseNow;
  LunarEclipse? _nextEclipse;
  DateTime? _nextEclipseCheckedAt;
  List<CyclePhase>? _cyclePhases;
  DateTime? _cyclePrevNew;
  bool _atmosphere = true;
  DateTime? _previewUntil;
  Timer? _ticker;
  Timer? _previewTimer;

  MoonProvider({DateTime Function()? clock, bool? southernHemisphere})
      : _clock = clock ?? DateTime.now,
        southernHemisphere = southernHemisphere ?? _detectSouthern() {
    _compute();
    _restore();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  static bool _detectSouthern() {
    final country = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    return country != null && _southernCountries.contains(country);
  }

  MoonSnapshot get snapshot => _snapshot;
  bool get atmosphereEnabled => _atmosphere;
  LunarEclipse? get eclipseNow => _eclipseNow;
  LunarEclipse? get nextEclipse => _nextEclipse;

  /// Cached cycle phases for the current lunation. Computed lazily and
  /// invalidated when the underlying new-moon anchor changes (~monthly).
  List<CyclePhase> get cyclePhases {
    if (_cyclePhases == null || _cyclePrevNew != _snapshot.previousNew.time) {
      _cyclePhases = MoonCalculator.cycleOf(_snapshot);
      _cyclePrevNew = _snapshot.previousNew.time;
    }
    return _cyclePhases!;
  }

  bool get isEclipsePreview =>
      _previewUntil != null && _clock().isBefore(_previewUntil!);

  /// Blood-moon mode: a real umbral eclipse right now, or the secret preview.
  bool get eclipseActive => _eclipseNow != null || isEclipsePreview;

  DateTime get now => _clock();

  /// Fired whenever blood-moon mode is shown (real eclipse or preview).
  VoidCallback? onEclipseSeen;

  void _compute() {
    final t = _clock();
    _snapshot = MoonCalculator.snapshot(t);
    _eclipseNow = MoonCalculator.eclipseInProgress(t);
    _refreshNextEclipse(t);
    if (_eclipseNow != null) onEclipseSeen?.call();
  }

  /// nextEclipse searches up to 3 years of full moons — expensive.
  /// Cache the result and only recompute when it expires or every 6 hours.
  void _refreshNextEclipse(DateTime t) {
    final cached = _nextEclipse;
    if (cached != null &&
        !cached.end.isBefore(t) &&
        _nextEclipseCheckedAt != null &&
        t.difference(_nextEclipseCheckedAt!).inHours < 6) {
      return;
    }
    _nextEclipse = MoonCalculator.nextEclipse(t);
    _nextEclipseCheckedAt = t;
  }

  void refresh() {
    final before = (_snapshot.name, (_snapshot.illumination * 1000).round(), _eclipseNow?.greatest);
    _compute();
    final after = (_snapshot.name, (_snapshot.illumination * 1000).round(), _eclipseNow?.greatest);
    if (before != after) notifyListeners();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_atmosphereKey);
      if (saved != null && saved != _atmosphere) {
        _atmosphere = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setAtmosphereEnabled(bool enabled) async {
    _atmosphere = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_atmosphereKey, enabled);
    } catch (_) {}
  }

  /// Easter egg: long-press the moon to see what an eclipse looks like.
  void previewEclipse() {
    onEclipseSeen?.call();
    _previewUntil = _clock().add(eclipsePreviewLength);
    _previewTimer?.cancel();
    _previewTimer = Timer(eclipsePreviewLength, () {
      _previewUntil = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _previewTimer?.cancel();
    super.dispose();
  }
}
