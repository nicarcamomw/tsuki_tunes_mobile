import 'package:sensors_plus/sensors_plus.dart';

class MotionSample {
  final double x, y, z;
  /// Sensor time; only differences matter.
  final Duration t;

  const MotionSample(this.x, this.y, this.z, this.t);
}

typedef MotionSource = Stream<MotionSample> Function();

/// The phone's accelerometer at ~50 Hz, gravity included.
Stream<MotionSample> phoneAccelerometer() =>
    accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) =>
        MotionSample(e.x, e.y, e.z, Duration(microseconds: e.timestamp.microsecondsSinceEpoch)));
