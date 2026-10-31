import 'package:tsuki_tunes_mobile/di/injection.dart';

/// Puts [fake] in get_it in place of whatever was registered as [T], for
/// the rest of the test (flutter_test_config.dart resets get_it before the
/// next one). Everything resolved afterwards that depends on [T], use
/// cases included, gets the fake.
void useFake<T extends Object>(T fake) {
  if (getIt.isRegistered<T>()) getIt.unregister<T>();
  getIt.registerSingleton<T>(fake);
}
