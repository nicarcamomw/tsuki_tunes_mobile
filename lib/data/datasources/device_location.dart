import 'package:geolocator/geolocator.dart';
import '../../core/logger.dart';


final _log = Log.named('Location');

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

/// The phone's coarse location (about 2 km), the only kind the app declares.
class DeviceLocation implements LocationSource {
  @override
  Future<LocationResult> approximate({bool ask = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationResult(LocationStatus.denied);
      }
      // A recent fix from any app is enough for the weather and costs no
      // battery; otherwise ask for a low-accuracy one.
      final last = await Geolocator.getLastKnownPosition();
      final fresh = last != null &&
          DateTime.now().difference(last.timestamp) < const Duration(hours: 1);
      final pos = fresh
          ? last
          : await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 15),
              ),
            );
      return LocationResult(LocationStatus.ok, pos.latitude, pos.longitude);
    } catch (e) {
      _log.severe('failed: $e');
      return const LocationResult(LocationStatus.failed);
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
