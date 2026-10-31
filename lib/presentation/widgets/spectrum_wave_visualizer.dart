import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/constants/app_colors.dart';

/// Self-contained spectrum wave visualizer with its own Ticker.
/// For use in screens that don't already have a time driver.
class SpectrumWaveVisualizer extends StatefulWidget {
  final double height;
  final double intensity;

  const SpectrumWaveVisualizer({
    super.key,
    this.height = 48,
    this.intensity = 1.0,
  });

  @override
  State<SpectrumWaveVisualizer> createState() => _SpectrumWaveVisualizerState();
}

class _SpectrumWaveVisualizerState extends State<SpectrumWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1000000.0;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: SpectrumWavePainter(
              time: t,
              intensity: widget.intensity,
            ),
          );
        },
      ),
    );
  }
}

/// 4-layer organic audio spectrum wave painter.
/// Each layer uses multi-octave sinusoidal interference for natural motion:
///   fundamental + 2nd harmonic + 3rd harmonic + cross-modulation
/// with bass-breathing amplitude modulation and edge tapering.
class SpectrumWavePainter extends CustomPainter {
  final double time;
  final double intensity;

  const SpectrumWavePainter({required this.time, this.intensity = 1.0});

  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  // [timeSpeed, spatialFreq, amplitudeFraction, baseOpacity]
  static const _layers = <List<double>>[
    [0.55, 1.1, 0.92, 0.05],
    [0.90, 1.7, 0.68, 0.10],
    [1.40, 2.5, 0.44, 0.18],
    [2.00, 3.6, 0.26, 0.30],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h * 0.5;

    for (int li = 0; li < _layers.length; li++) {
      final cfg = _layers[li];
      final speed = cfg[0];
      final freq = cfg[1];
      final maxAmp = midY * cfg[2];
      final baseOp = cfg[3] * intensity;
      final phase = li * pi * 0.618;
      final dir = li.isEven ? 1.0 : -1.0;

      final wavePath = Path();
      final fillPath = Path();
      const dx = 2.0;
      final steps = (w / dx).ceil();

      for (int i = 0; i <= steps; i++) {
        final x = min(i * dx, w);
        final nx = x / w;

        // Edge taper — smooth power-curve fade at both ends
        final taper = _pow(sin(nx * pi), 1.8);

        // Multi-octave organic wave synthesis
        final t = time;
        final o1 = sin(nx * freq * 2 * pi + t * speed * dir + phase);
        final o2 = sin(nx * freq * 1.7 * 2 * pi -
                t * speed * 0.65 * dir +
                phase * 1.4) *
            0.5;
        final o3 = sin(nx * freq * 2.4 * 2 * pi +
                t * speed * 1.3 * dir +
                phase * 0.7) *
            0.25;
        final o4 = cos(nx * freq * 0.6 * 2 * pi -
                t * speed * 0.35 +
                phase * 2.2) *
            0.12;

        // Bass breathing modulation — sharp cubic pulse
        final breath = _pow(max(0.0, sin(t * 2.2 + li * 0.6)), 3.0) * 0.35;

        final sample = (o1 + o2 + o3 + o4) / 1.87 * (1.0 + breath);
        final y = midY + sample * maxAmp * taper;

        if (i == 0) {
          wavePath.moveTo(x, y);
          fillPath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      // Fill under the wave crest
      fillPath.lineTo(w, h);
      fillPath.lineTo(0, h);
      fillPath.close();

      _fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withValues(alpha: baseOp * 0.7),
          AppColors.accent.withValues(alpha: baseOp * 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(fillPath, _fillPaint);

      // Outer glow on crest
      _glowPaint.color = AppColors.accent.withValues(alpha: baseOp * 0.25);
      canvas.drawPath(wavePath, _glowPaint);

      // Crisp crest line
      _strokePaint.color = AppColors.accent.withValues(alpha: baseOp * 0.9);
      canvas.drawPath(wavePath, _strokePaint);
    }
  }

  static double _pow(double base, double exp) => pow(base, exp).toDouble();

  @override
  bool shouldRepaint(covariant SpectrumWavePainter old) =>
      old.time != time || old.intensity != intensity;
}
