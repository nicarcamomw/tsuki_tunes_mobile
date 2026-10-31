part of 'onboarding_screen.dart';

class _AnimatedSlide extends StatelessWidget {
  final ValueNotifier<double> timeNotifier;
  final Widget Function(double t) builder;

  const _AnimatedSlide({required this.timeNotifier, required this.builder});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: timeNotifier,
        builder: (context, t, _) => builder(t),
      ),
    );
  }
}

class _OnboardingParticle {
  final double xRatio;
  final double speed;
  final double size;
  final double opacity;
  final double phase;

  _OnboardingParticle(Random rng)
      : xRatio = rng.nextDouble(),
        speed = 0.04 + rng.nextDouble() * 0.07,
        size = 1.0 + rng.nextDouble() * 2.0,
        opacity = 0.15 + rng.nextDouble() * 0.45,
        phase = rng.nextDouble() * 2 * pi;
}

class _CyberParticlesPainter extends CustomPainter {
  final List<_OnboardingParticle> particles;
  final double time;

  static final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  const _CyberParticlesPainter({
    required this.particles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final yProgress = (p.phase + time * p.speed) % 1.0;
      final y = h - (yProgress * h);
      final x = p.xRatio * w + sin(time * 1.2 + p.phase) * 12.0;

      final alpha = (sin(yProgress * pi) * p.opacity).clamp(0.0, 1.0);
      _particlePaint.color = AppColors.accent.withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), p.size, _particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberParticlesPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter();

  static final Paint _gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = const Color(0xFF161622).withValues(alpha: 0.6);

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
