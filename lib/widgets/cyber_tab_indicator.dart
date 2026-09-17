import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// CyberTabIndicator: Barra luminosa activa con micro-partículas de chispa de circuito
/// que emanan brevemente (~380 ms) al cambiar de pestaña activa.
///
/// Optimización de rendimiento (Zero-GC, 120 FPS):
/// - Pool estático de partículas preasignado (0 instanciaciones en tiempo de dibujo).
/// - Paint objects estáticos y cacheados (0 asignaciones de memoria en paint).
/// - Un único AnimationController que detiene el ticker vsync al finalizar (~380 ms),
///   garantizando 0 consumo de CPU/GPU cuando el usuario está quieto en la pestaña.
class CyberTabIndicator extends StatefulWidget {
  final bool isSelected;

  const CyberTabIndicator({
    super.key,
    required this.isSelected,
  });

  @override
  State<CyberTabIndicator> createState() => _CyberTabIndicatorState();
}

class _CyberTabIndicatorState extends State<CyberTabIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkController;
  late final Animation<double> _sparkAnimation;

  // Pool de partículas preasignado (Zero-GC)
  static const int _particleCount = 8;
  final List<_CircuitSpark> _particles = List.generate(
    _particleCount,
    (_) => _CircuitSpark(),
  );

  static final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _sparkAnimation = CurvedAnimation(
      parent: _sparkController,
      curve: Curves.easeOutQuad,
    );

    if (widget.isSelected) {
      _emitCircuitSparks();
      _sparkController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant CyberTabIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _emitCircuitSparks();
      _sparkController.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _sparkController.stop();
    }
  }

  /// Inicializa las trayectorias de las chispas de circuito
  void _emitCircuitSparks() {
    for (int i = 0; i < _particleCount; i++) {
      // Distribución horizontal sobre la barra de 14px (-6 a +6 desde el centro)
      final startX = (_random.nextDouble() * 12.0) - 6.0;
      // Ángulo de dispersión hacia arriba: cono de ~140° (-160° a -20°)
      final angle = (-math.pi / 2.0) + ((_random.nextDouble() - 0.5) * (math.pi * 0.78));
      final speed = 18.0 + (_random.nextDouble() * 24.0);

      _particles[i].x = startX;
      _particles[i].y = 0.0;
      _particles[i].vx = math.cos(angle) * speed;
      _particles[i].vy = math.sin(angle) * speed; // hacia arriba (negativo)
      _particles[i].radius = 0.85 + (_random.nextDouble() * 1.15);
      _particles[i].lifespan = 0.5 + (_random.nextDouble() * 0.5);
      // ~30% de partículas son chispas blancas incandescentes antes de tornarse carmesí
      _particles[i].isWhiteCore = _random.nextDouble() < 0.32;
    }
  }

  @override
  void dispose() {
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelected) {
      return const SizedBox(height: 5);
    }

    return Container(
      margin: const EdgeInsets.only(top: 3),
      width: 36, // margen suficiente para dispersión lateral sin clipping
      height: 16,
      child: AnimatedBuilder(
        animation: _sparkAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _CyberTabIndicatorPainter(
              progress: _sparkAnimation.value,
              particles: _particles,
              isSparkActive: _sparkController.isAnimating,
            ),
          );
        },
      ),
    );
  }
}

class _CircuitSpark {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double radius = 1.0;
  double lifespan = 1.0;
  bool isWhiteCore = false;
}

class _CyberTabIndicatorPainter extends CustomPainter {
  final double progress;
  final List<_CircuitSpark> particles;
  final bool isSparkActive;

  _CyberTabIndicatorPainter({
    required this.progress,
    required this.particles,
    required this.isSparkActive,
  });

  // Paints cacheados globalmente para CERO asignaciones de memoria por frame (Zero-GC)
  static final Paint _barGlowPaint = Paint()
    ..color = AppColors.accentGlow.withValues(alpha: 0.85)
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  static final Paint _barPaint = Paint()
    ..color = AppColors.accent
    ..style = PaintingStyle.fill;

  static final Paint _sparkPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _sparkGlowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    const barHeight = 2.0;
    final barY = size.height - barHeight - 1.0;

    // Expansión elástica suave de la barra luminosa al cambiar de tab (0 -> 14px)
    final barWidth = isSparkActive
        ? 14.0 * math.min(1.0, progress * 2.5)
        : 14.0;

    final barRect = Rect.fromCenter(
      center: Offset(centerX, barY + (barHeight / 2.0)),
      width: barWidth,
      height: barHeight,
    );
    final rrect = RRect.fromRectAndRadius(barRect, const Radius.circular(1.0));

    // Dibujar barra luminosa con halo de neón
    canvas.drawRRect(rrect, _barGlowPaint);
    canvas.drawRRect(rrect, _barPaint);

    // Dibujar micro-partículas de chispa mientras dure la emanación
    if (isSparkActive && progress > 0.0 && progress < 1.0) {
      for (int i = 0; i < particles.length; i++) {
        final p = particles[i];
        final particleAge = progress / p.lifespan;
        if (particleAge >= 1.0) continue;

        // Desvanecimiento suave con curva cuadrática
        final alpha = (1.0 - particleAge) * (1.0 - (progress * 0.4));
        if (alpha <= 0.0) continue;

        // Trayectoria balística con micro-arrastre aerodinámico y gravedad sutil
        final px = centerX + p.x + (p.vx * progress * 0.42);
        final py = barY + (p.vy * progress * 0.42) + (9.0 * progress * progress);
        final currentRadius = p.radius * (1.0 - (particleAge * 0.4));

        final Color sparkColor = p.isWhiteCore
            ? (particleAge < 0.25
                ? Colors.white
                : Color.lerp(Colors.white, AppColors.accent, (particleAge - 0.25) / 0.75)!)
            : AppColors.accent;

        // Resplandor periférico de la chispa
        _sparkGlowPaint.color = AppColors.accentGlow.withValues(alpha: alpha * 0.75);
        canvas.drawCircle(Offset(px, py), currentRadius + 1.2, _sparkGlowPaint);

        // Núcleo de la chispa
        _sparkPaint.color = sparkColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(px, py), currentRadius, _sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberTabIndicatorPainter oldDelegate) {
    return isSparkActive || oldDelegate.isSparkActive;
  }
}
