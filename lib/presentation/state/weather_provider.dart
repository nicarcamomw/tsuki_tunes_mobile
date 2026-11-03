import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../data/datasources/device_location.dart';
import '../../data/datasources/weather_service.dart';


final _log = Log.named('Weather');

enum WeatherSource { device, place }

/// Live weather for the home screen. Off until the listener turns it on and
/// picks where: the phone's approximate location or a city typed by hand.
/// It refreshes at most every half hour while the app is open, never in the
/// background.
class WeatherProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _enabledKey = 'weather_enabled';
  static const _sourceKey = 'weather_source';
  static const _placeKey = 'weather_place';
  static const _lastKey = 'weather_last';
  static const _offeredKey = 'weather_rain_offered_at';
  static const _rainEpisodeKey = 'weather_rain_episode_offered';

  static const Duration maxAge = Duration(minutes: 30);
  /// Showers come and go; a new offer needs at least this long since the last.
  static const Duration offerGap = Duration(hours: 3);

  final WeatherService _service;
  final LocationSource _location;
  final DateTime Function() _now;

  WeatherProvider({
    WeatherService? service,
    LocationSource? location,
    @visibleForTesting DateTime Function()? clock,
    bool observeLifecycle = true,
  })  : _service = service ?? WeatherService(),
        _location = location ?? DeviceLocation(),
        _now = clock ?? DateTime.now {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _observing = observeLifecycle;
    ready = _load();
  }

  late final Future<void> ready;
  bool _observing = false;
  bool _enabled = false;
  WeatherSource _source = WeatherSource.device;
  Place? _place;
  WeatherNow? _current;
  bool _loading = false;
  LocationStatus? _locationProblem;
  bool _offline = false;
  bool _rainOffer = false;
  bool _offeredThisRain = false;
  DateTime? _offeredAt;
  Timer? _timer;

  bool get enabled => _enabled;
  WeatherSource get source => _source;
  Place? get place => _place;
  /// Null while unknown or too old to trust (over 3 hours).
  WeatherNow? get current {
    final c = _current;
    if (c == null || _now().difference(c.fetchedAt) > const Duration(hours: 3)) return null;
    return c;
  }

  bool get loading => _loading;
  LocationStatus? get locationProblem => _locationProblem;
  bool get offline => _offline;
  /// "It's raining where you are: play something for the rain?"
  bool get rainOffer => _enabled && _rainOffer;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _source = prefs.getString(_sourceKey) == 'place' ? WeatherSource.place : WeatherSource.device;
      final rawPlace = prefs.getString(_placeKey);
      _place = rawPlace == null ? null : Place.fromJson(jsonDecode(rawPlace));
      final rawLast = prefs.getString(_lastKey);
      _current = rawLast == null ? null : WeatherNow.fromJson(jsonDecode(rawLast));
      final offered = prefs.getString(_offeredKey);
      _offeredAt = offered == null ? null : DateTime.tryParse(offered);
      _offeredThisRain = prefs.getBool(_rainEpisodeKey) ?? false;
    } catch (e) {
      _log.severe('load error: $e');
    }
    notifyListeners();
    if (_enabled) {
      _startTimer();
      unawaited(refresh());
    }
  }

  /// Turns the weather on with the phone's approximate location. Asks for
  /// the permission if needed; returns what happened.
  Future<LocationStatus> useDeviceLocation() async {
    _loading = true;
    notifyListeners();
    final loc = await _location.approximate(ask: true);
    _loading = false;
    if (!loc.ok) {
      _locationProblem = loc.status;
      notifyListeners();
      return loc.status;
    }
    _locationProblem = null;
    _source = WeatherSource.device;
    await _setEnabled(true);
    await _fetch(loc.latitude!, loc.longitude!);
    return LocationStatus.ok;
  }

  /// Turns the weather on for a chosen city.
  Future<void> usePlace(Place place) async {
    _place = place;
    _source = WeatherSource.place;
    _locationProblem = null;
    await _setEnabled(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_placeKey, jsonEncode(place.toJson()));
    } catch (_) {}
    await _fetch(place.latitude, place.longitude);
  }

  Future<List<Place>?> searchPlaces(String name, {String language = 'es'}) =>
      _service.search(name, language: language);

  /// Whether turning it on needs a location choice first.
  bool get hasLocationChoice => _source == WeatherSource.place ? _place != null : true;

  Future<void> disable() => _setEnabled(false);

  Future<void> _setEnabled(bool value) async {
    _enabled = value;
    if (value) {
      _startTimer();
    } else {
      _timer?.cancel();
      _rainOffer = false;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      await prefs.setString(_sourceKey, _source.name);
    } catch (_) {}
  }

  /// Fetches the weather if it is older than [maxAge] (or [force]).
  Future<void> refresh({bool force = false}) async {
    if (!_enabled || _loading) return;
    final c = _current;
    if (!force && c != null && _now().difference(c.fetchedAt) < maxAge) {
      _updateRainOffer();
      return;
    }
    if (_source == WeatherSource.place) {
      final p = _place;
      if (p != null) await _fetch(p.latitude, p.longitude);
      return;
    }
    _loading = true;
    notifyListeners();
    final loc = await _location.approximate();
    _loading = false;
    if (!loc.ok) {
      _locationProblem = loc.status;
      notifyListeners();
      return;
    }
    _locationProblem = null;
    await _fetch(loc.latitude!, loc.longitude!);
  }

  Future<void> _fetch(double lat, double lon) async {
    _loading = true;
    notifyListeners();
    final w = await _service.current(lat, lon, now: _now());
    _loading = false;
    _offline = w == null;
    if (w != null) {
      _current = w;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastKey, jsonEncode(w.toJson()));
      } catch (_) {}
      _updateRainOffer();
    }
    notifyListeners();
  }

  /// One offer per rain: it comes back only after a dry reading and a gap.
  void _updateRainOffer() {
    final c = current;
    if (c == null) return;
    if (!c.isRaining) {
      _rainOffer = false;
      if (_offeredThisRain) {
        _offeredThisRain = false;
        unawaited(_persistEpisode());
      }
      return;
    }
    final last = _offeredAt;
    final gapOk = last == null || _now().difference(last) >= offerGap;
    _rainOffer = !_offeredThisRain && gapOk;
  }

  /// The listener answered the offer (either way).
  Future<void> dismissRainOffer() async {
    _rainOffer = false;
    _offeredThisRain = true;
    _offeredAt = _now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offeredKey, _offeredAt!.toIso8601String());
    } catch (_) {}
    await _persistEpisode();
  }

  Future<void> _persistEpisode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rainEpisodeKey, _offeredThisRain);
    } catch (_) {}
  }

  Future<void> openAppSettings() => _location.openAppSettings();
  Future<void> openLocationSettings() => _location.openLocationSettings();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(maxAge, (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(refresh());
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
