/// The weather where the user is, as the app shows it.
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

/// The part of the day at [local] time.
DayPart dayPartAt(DateTime local) => switch (local.hour) {
      < 6 => DayPart.lateNight,
      < 12 => DayPart.morning,
      < 20 => DayPart.afternoon,
      _ => DayPart.night,
    };
