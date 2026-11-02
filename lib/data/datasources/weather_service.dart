import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../core/logger.dart';


final _log = Log.named('Weather');

enum Sky { clear, fewClouds, cloudy, overcast, fog, drizzle, rain, snow, storm }

enum DayPart { lateNight, morning, afternoon, night }

class WeatherNow {
  final Sky sky;
  final double temperature;
  final bool isDay;
  /// Millimetres in the last hour.
  final double precipitation;
  /// Local time at the place, as Open-Meteo reports it.
  final DateTime localTime;
  final DateTime fetchedAt;

  const WeatherNow({
    required this.sky,
    required this.temperature,
    required this.isDay,
    required this.precipitation,
    required this.localTime,
    required this.fetchedAt,
  });

  bool get isRaining => sky == Sky.drizzle || sky == Sky.rain || sky == Sky.storm;

  Map<String, Object> toJson() => {
        'sky': sky.name,
        'temp': temperature,
        'day': isDay,
        'precip': precipitation,
        'local': localTime.toIso8601String(),
        'at': fetchedAt.toIso8601String(),
      };

  static WeatherNow? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return WeatherNow(
        sky: Sky.values.byName(j['sky'] as String),
        temperature: (j['temp'] as num).toDouble(),
        isDay: j['day'] as bool,
        precipitation: (j['precip'] as num).toDouble(),
        localTime: DateTime.parse(j['local'] as String),
        fetchedAt: DateTime.parse(j['at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

class Place {
  final String name;
  /// Region and country, for telling same-named places apart.
  final String detail;
  final double latitude;
  final double longitude;

  const Place(this.name, this.detail, this.latitude, this.longitude);

  Map<String, Object> toJson() => {'n': name, 'd': detail, 'lat': latitude, 'lon': longitude};

  static Place? fromJson(Object? j) {
    if (j is! Map) return null;
    final n = j['n'], lat = j['lat'], lon = j['lon'];
    if (n is! String || lat is! num || lon is! num) return null;
    return Place(n, j['d'] is String ? j['d'] as String : '', lat.toDouble(), lon.toDouble());
  }
}

/// Open-Meteo: free, no key, no account.
class WeatherService {
  final http.Client _client;
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Coordinates are rounded to ~1 km before leaving the phone: plenty for
  /// the weather, and the exact position is never sent anywhere.
  static double round(double v) => (v * 100).roundToDouble() / 100;

  static Uri forecastUri(double lat, double lon) => Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': round(lat).toString(),
        'longitude': round(lon).toString(),
        'current': 'temperature_2m,weather_code,is_day,precipitation',
        'timezone': 'auto',
      });

  static Uri searchUri(String name, String language) =>
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name,
        'count': '6',
        'language': language,
        'format': 'json',
      });

  Future<WeatherNow?> current(double lat, double lon, {DateTime? now}) async {
    try {
      final res = await _client.get(forecastUri(lat, lon)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return parseCurrent(res.body, now: now ?? DateTime.now());
    } catch (e) {
      _log.severe('forecast failed: $e');
      return null;
    }
  }

  Future<List<Place>?> search(String name, {String language = 'es'}) async {
    if (name.trim().length < 2) return const [];
    try {
      final res = await _client
          .get(searchUri(name.trim(), language))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return parsePlaces(res.body);
    } catch (e) {
      _log.severe('search failed: $e');
      return null;
    }
  }

  static WeatherNow? parseCurrent(String body, {required DateTime now}) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final c = j['current'] as Map<String, dynamic>;
      return WeatherNow(
        sky: skyFor((c['weather_code'] as num).toInt()),
        temperature: (c['temperature_2m'] as num).toDouble(),
        isDay: (c['is_day'] as num?)?.toInt() == 1,
        precipitation: (c['precipitation'] as num?)?.toDouble() ?? 0,
        // Local wall time at the place ("2026-10-26T18:15", no offset).
        localTime: DateTime.parse(c['time'] as String),
        fetchedAt: now,
      );
    } catch (e) {
      _log.fine('unexpected forecast: $e');
      return null;
    }
  }

  static List<Place> parsePlaces(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final results = j['results'] as List? ?? const [];
      return [
        for (final r in results.cast<Map<String, dynamic>>())
          Place(
            r['name'] as String,
            [r['admin1'], r['country']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
            (r['latitude'] as num).toDouble(),
            (r['longitude'] as num).toDouble(),
          ),
      ];
    } catch (e) {
      _log.fine('unexpected search: $e');
      return const [];
    }
  }

  /// WMO weather interpretation codes, as Open-Meteo documents them.
  static Sky skyFor(int code) => switch (code) {
        0 => Sky.clear,
        1 => Sky.fewClouds,
        2 => Sky.cloudy,
        3 => Sky.overcast,
        45 || 48 => Sky.fog,
        51 || 53 || 55 || 56 || 57 => Sky.drizzle,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => Sky.rain,
        71 || 73 || 75 || 77 || 85 || 86 => Sky.snow,
        95 || 96 || 99 => Sky.storm,
        _ => Sky.cloudy,
      };

  static DayPart dayPart(DateTime local) => switch (local.hour) {
        < 6 => DayPart.lateNight,
        < 12 => DayPart.morning,
        < 20 => DayPart.afternoon,
        _ => DayPart.night,
      };
}
