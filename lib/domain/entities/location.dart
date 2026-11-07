/// Where the user is, roughly, for the local weather.
enum LocationStatus { ok, denied, deniedForever, serviceOff, failed }

class LocationResult {
  final LocationStatus status;
  final double? latitude;
  final double? longitude;

  const LocationResult(this.status, [this.latitude, this.longitude]);

  bool get ok => status == LocationStatus.ok;
}

abstract class LocationSource {
  /// Approximate position, asking for permission if [ask] and not yet given.
  Future<LocationResult> approximate({bool ask = false});
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}
