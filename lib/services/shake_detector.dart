import 'dart:math';

/// Detects a deliberate shake of the phone.
///
/// A shake is half a second where most samples carry a strong acceleration.
/// Single knocks (setting the phone down, a bump in a pocket) and walking
/// only produce short spikes, so they never fill the window. Same idea as
/// Square's Seismic, which has been used for years in production apps.
class ShakeDetector {
  /// Acceleration magnitude (m/s², gravity included) that counts as strong.
  /// About 1.45 g; resting reads 1 g.
  static const double threshold = 14.2;
  static const Duration window = Duration(milliseconds: 500);
  /// Share of samples in the window that must be strong.
  static const double requiredShare = 0.75;
  static const int minSamples = 8;
  /// After a shake, ignore motion for this long (the arm is still moving).
  static const Duration cooldown = Duration(milliseconds: 1500);

  final List<(Duration, bool)> _samples = [];
  Duration? _lastShake;

  /// Adds a sample taken at [t]. Returns true once per shake.
  bool add(double x, double y, double z, Duration t) {
    if (_samples.isNotEmpty && t < _samples.last.$1) _samples.clear();
    final strong = sqrt(x * x + y * y + z * z) > threshold;
    _samples.add((t, strong));
    while (_samples.isNotEmpty && t - _samples.first.$1 > window) {
      _samples.removeAt(0);
    }

    final last = _lastShake;
    if (last != null && t - last < cooldown) return false;
    if (_samples.length < minSamples) return false;
    // The window must really span about half a second, not a burst.
    if (t - _samples.first.$1 < window * 0.8) return false;

    final strongCount = _samples.where((s) => s.$2).length;
    if (strongCount < _samples.length * requiredShare) return false;

    _lastShake = t;
    _samples.clear();
    return true;
  }

  void reset() {
    _samples.clear();
    _lastShake = null;
  }
}
