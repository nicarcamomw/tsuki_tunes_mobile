import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// CyberNavIcon: Ícono vectorial temático Cyberpunk / Japanese Folklore
/// dibujado en Canvas de alto rendimiento (Zero-GC, 120 FPS).
///
/// Pestañas:
/// - 0 (HOME): Torii Gate Cyberpunk (鸟居) con pilares neón y núcleo pulsante.
/// - 1 (SEARCH): Visor HUD / Escáner Óptico Oni con retícula y bloqueo de objetivo.
/// - 2 (LIBRARY): Bóveda / Cartucho Tecnológico con disco vinilo holográfico emergente.
class CyberNavIcon extends StatefulWidget {
  final int index;
  final bool isSelected;
  final double size;

  const CyberNavIcon({
    super.key,
    required this.index,
    required this.isSelected,
    this.size = 24.0,
  });

  @override
  State<CyberNavIcon> createState() => _CyberNavIconState();
}

class _CyberNavIconState extends State<CyberNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _curveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant CyberNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, child) {
        final progress = _curveAnimation.value;

        // Micro-shake electromagnético senoidal (~180ms) en la fase inicial de activación
        final double shakeOffset = widget.isSelected && progress < 0.85
            ? math.sin(progress * math.pi * 4.0) * (1.0 - progress) * 1.8
            : 0.0;

        // Micro-escala elástica sutil al activarse (1.14 -> 1.0)
        final double scale = widget.isSelected
            ? 1.0 + (math.sin(progress * math.pi) * 0.12)
            : 1.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _CyberNavIconPainter(
                  index: widget.index,
                  progress: progress,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CyberNavIconPainter extends CustomPainter {
  final int index;
  final double progress;

  _CyberNavIconPainter({
    required this.index,
    required this.progress,
  });

  static const Color _inactiveColor = Color(0xFF717688);

  // Cached Paint objects (Zero-GC)
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _fillGlow = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

  static final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _discPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  static final Paint _groovePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final Paint _barPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5;

  static final Paint _laserGlow = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

  // Reusable Path objects (Zero-GC)
  static final Path _p1 = Path();
  static final Path _p2 = Path();
  static final Path _p3 = Path();
  static final Path _p4 = Path();
  static final Path _p5 = Path();
  static final Path _p6 = Path();
  static final Path _p7 = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final currentColor = Color.lerp(_inactiveColor, AppColors.accent, progress)!;
    _strokePaint.color = currentColor;

    final hasGlow = progress > 0.08;
    if (hasGlow) {
      _glowPaint.color = AppColors.accentGlow.withValues(alpha: 0.7 * progress);
    }

    switch (index) {
      case 0:
        _drawCyberTorii(canvas, size, progress, _strokePaint, hasGlow ? _glowPaint : null);
        break;
      case 1:
        _drawCyberScan(canvas, size, progress, _strokePaint, hasGlow ? _glowPaint : null);
        break;
      case 2:
        _drawCyberVault(canvas, size, progress, _strokePaint, hasGlow ? _glowPaint : null);
        break;
    }
  }

  /// 0. HOME: Cyber Torii Gate (Santuario Shinto Neón)
  void _drawCyberTorii(
    Canvas canvas,
    Size size,
    double t,
    Paint strokePaint,
    Paint? glowPaint,
  ) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;

    // Dintel superior curvado con remates angulares (Kasagi)
    final kasagi = _p1
      ..reset()
      ..moveTo(2.0 * sx, 5.8 * sy)
      ..quadraticBezierTo(12.0 * sx, 3.8 * sy, 22.0 * sx, 5.8 * sy);

    // Borde biselado del dintel superior (Cyber bevel)
    final kasagiTop = _p2
      ..reset()
      ..moveTo(1.5 * sx, 4.4 * sy)
      ..quadraticBezierTo(12.0 * sx, 2.4 * sy, 22.5 * sx, 4.4 * sy);

    // Travesaño recto inferior (Nuki)
    final nuki = _p3
      ..reset()
      ..moveTo(4.2 * sx, 8.6 * sy)
      ..lineTo(19.8 * sx, 8.6 * sy);

    // Pilares verticales (Hashira)
    final leftPillar = _p4
      ..reset()
      ..moveTo(7.0 * sx, 8.6 * sy)
      ..lineTo(6.0 * sx, 21.0 * sy);

    final rightPillar = _p5
      ..reset()
      ..moveTo(17.0 * sx, 8.6 * sy)
      ..lineTo(18.0 * sx, 21.0 * sy);

    // Zócalos o bases de los pilares (Nemaki)
    final leftBase = _p6
      ..reset()
      ..moveTo(4.2 * sx, 21.0 * sy)
      ..lineTo(7.8 * sx, 21.0 * sy);

    final rightBase = _p7
      ..reset()
      ..moveTo(16.2 * sx, 21.0 * sy)
      ..lineTo(19.8 * sx, 21.0 * sy);

    if (glowPaint != null) {
      canvas.drawPath(kasagi, glowPaint);
      canvas.drawPath(kasagiTop, glowPaint);
      canvas.drawPath(nuki, glowPaint);
      canvas.drawPath(leftPillar, glowPaint);
      canvas.drawPath(rightPillar, glowPaint);
    }

    canvas.drawPath(kasagi, strokePaint);
    canvas.drawPath(kasagiTop, strokePaint);
    canvas.drawPath(nuki, strokePaint);
    canvas.drawPath(leftPillar, strokePaint);
    canvas.drawPath(rightPillar, strokePaint);
    canvas.drawPath(leftBase, strokePaint);
    canvas.drawPath(rightBase, strokePaint);

    // Núcleo Shinto / Cyber Sol central
    final orbCenter = Offset(12.0 * sx, (14.2 - (t * 1.2)) * sy);
    if (t > 0.0) {
      final orbRadius = (2.2 + (t * 0.9)) * sx;

      if (glowPaint != null) {
        _fillGlow.color = AppColors.accentGlow.withValues(alpha: 0.85 * t);
        canvas.drawCircle(orbCenter, orbRadius + 1.2, _fillGlow);
      }

      _fillPaint.color = AppColors.accent.withValues(alpha: t);
      canvas.drawCircle(orbCenter, orbRadius, _fillPaint);

      // Micro-punto láser blanco de alta intensidad en el núcleo
      _fillPaint.color = Colors.white.withValues(alpha: 0.95 * t);
      canvas.drawCircle(orbCenter, 1.1 * sx, _fillPaint);
    } else {
      // Estado inactivo: punto wireframe sutil
      _fillPaint.color = strokePaint.color.withValues(alpha: 0.45);
      canvas.drawCircle(orbCenter, 1.1 * sx, _fillPaint);
    }
  }

  /// 1. SEARCH: Cyber HUD / Escáner Óptico Oni
  void _drawCyberScan(
    Canvas canvas,
    Size size,
    double t,
    Paint strokePaint,
    Paint? glowPaint,
  ) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;

    final cx = 11.0 * sx;
    final cy = 11.0 * sy;
    final lensRadius = 5.3 * sx;

    // Desplazamiento dinámico de los esquineros HUD (expansión al detectar objetivo)
    final bOffset = t * 1.2 * sx;

    // Esquinero superior-izquierdo
    final tl = _p1
      ..reset()
      ..moveTo((4.5 * sx) - bOffset, (7.5 * sy) - bOffset)
      ..lineTo((4.5 * sx) - bOffset, (4.5 * sy) - bOffset)
      ..lineTo((7.5 * sx) - bOffset, (4.5 * sy) - bOffset);

    // Esquinero superior-derecho
    final tr = _p2
      ..reset()
      ..moveTo((17.5 * sx) + bOffset, (4.5 * sy) - bOffset)
      ..lineTo((17.5 * sx) + bOffset, (7.5 * sy) - bOffset);

    // Esquinero inferior-izquierdo
    final bl = _p3
      ..reset()
      ..moveTo((4.5 * sx) - bOffset, (14.5 * sy) + bOffset)
      ..lineTo((4.5 * sx) - bOffset, (17.5 * sy) + bOffset)
      ..lineTo((7.5 * sx) - bOffset, (17.5 * sy) + bOffset);

    // Brazo táctico diagonal
    final handle = _p4
      ..reset()
      ..moveTo(15.0 * sx, 15.0 * sy)
      ..lineTo(21.2 * sx, 21.2 * sy);

    // Muesca angular cyber en el mango
    final notch = _p5
      ..reset()
      ..moveTo(19.2 * sx, 21.2 * sy)
      ..lineTo(21.2 * sx, 19.2 * sy);

    if (glowPaint != null) {
      canvas.drawCircle(Offset(cx, cy), lensRadius, glowPaint);
      canvas.drawPath(tl, glowPaint);
      canvas.drawPath(tr, glowPaint);
      canvas.drawPath(bl, glowPaint);
      canvas.drawPath(handle, glowPaint);
    }

    canvas.drawCircle(Offset(cx, cy), lensRadius, strokePaint);
    canvas.drawPath(tl, strokePaint);
    canvas.drawPath(tr, strokePaint);
    canvas.drawPath(bl, strokePaint);
    canvas.drawPath(handle, strokePaint);
    canvas.drawPath(notch, strokePaint);

    // Retícula de telemetría y punto de fijación láser
    if (t > 0.0) {
      // Anillo interno de escaneo
      _discPaint
        ..color = AppColors.accent.withValues(alpha: 0.8 * t)
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(cx, cy), 2.4 * sx, _discPaint);

      // Líneas de cruce de mira (Crosshairs)
      _barPaint
        ..color = AppColors.accent.withValues(alpha: t)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(cx, cy - lensRadius), Offset(cx, cy - lensRadius + 2.0 * sy), _barPaint);
      canvas.drawLine(Offset(cx, cy + lensRadius), Offset(cx, cy + lensRadius - 2.0 * sy), _barPaint);
      canvas.drawLine(Offset(cx - lensRadius, cy), Offset(cx - lensRadius + 2.0 * sx, cy), _barPaint);

      // Destello láser rojo/blanco central
      _fillPaint.color = Colors.white.withValues(alpha: t);
      canvas.drawCircle(Offset(cx, cy), 1.2 * sx, _fillPaint);

      if (glowPaint != null) {
        _laserGlow.color = AppColors.accentGlow.withValues(alpha: t);
        canvas.drawCircle(Offset(cx, cy), 2.6 * sx, _laserGlow);
      }
    }
  }

  /// 2. LIBRARY: Cartucho Tecnológico con Disco Vinilo Holográfico Emergente
  void _drawCyberVault(
    Canvas canvas,
    Size size,
    double t,
    Paint strokePaint,
    Paint? glowPaint,
  ) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;

    // Cuerpo de la bóveda/cartucho con esquinas biseladas tech
    final vaultBody = _p1
      ..reset()
      ..moveTo(6.5 * sx, 10.5 * sy)
      ..lineTo(17.5 * sx, 10.5 * sy)
      ..lineTo(20.5 * sx, 13.5 * sy)
      ..lineTo(20.5 * sx, 21.0 * sy)
      ..lineTo(3.5 * sx, 21.0 * sy)
      ..lineTo(3.5 * sx, 13.5 * sy)
      ..close();

    // Ranura de inserción superior
    final slotLine = _p2
      ..reset()
      ..moveTo(6.5 * sx, 11.8 * sy)
      ..lineTo(17.5 * sx, 11.8 * sy);

    // Disco vinilo holográfico emergiendo verticalmente
    final discCenterY = (10.5 - (t * 3.3)) * sy;
    final discCenterX = 12.0 * sx;
    final discRadius = 5.2 * sx;

    _discPaint
      ..color = t > 0.0
          ? Color.lerp(strokePaint.color, AppColors.accent, t)!
          : strokePaint.color.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;

    if (glowPaint != null && t > 0.1) {
      canvas.drawCircle(Offset(discCenterX, discCenterY), discRadius, glowPaint);
    }
    canvas.drawCircle(Offset(discCenterX, discCenterY), discRadius, _discPaint);

    // Surco concéntrico del vinilo holográfico
    _groovePaint
      ..color = _discPaint.color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(discCenterX, discCenterY), discRadius * 0.62, _groovePaint);

    // Orificio central del disco
    _fillPaint.color = t > 0.0 ? AppColors.accent : strokePaint.color;
    canvas.drawCircle(Offset(discCenterX, discCenterY), 1.2 * sx, _fillPaint);

    // Relleno de la bóveda para ocultar limpiamente la mitad inferior del disco emergente
    _fillPaint.color = AppColors.bgDeep;
    canvas.drawPath(vaultBody, _fillPaint);

    // Trazos y brillo del cartucho
    if (glowPaint != null) {
      canvas.drawPath(vaultBody, glowPaint);
      canvas.drawPath(slotLine, glowPaint);
    }
    canvas.drawPath(vaultBody, strokePaint);
    canvas.drawPath(slotLine, strokePaint);

    // Barras de ecualizador / telemetría de audio grabadas en la carcasa
    _barPaint
      ..color = t > 0.0 ? AppColors.accent : strokePaint.color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    final b1H = (3.0 + (t * 1.5)) * sy;
    final b2H = (5.0 + (t * 2.2)) * sy;
    final b3H = (3.8 + (t * 1.0)) * sy;
    final baseY = 19.0 * sy;

    canvas.drawLine(Offset(8.5 * sx, baseY), Offset(8.5 * sx, baseY - b1H), _barPaint);
    canvas.drawLine(Offset(12.0 * sx, baseY), Offset(12.0 * sx, baseY - b2H), _barPaint);
    canvas.drawLine(Offset(15.5 * sx, baseY), Offset(15.5 * sx, baseY - b3H), _barPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberNavIconPainter oldDelegate) {
    return oldDelegate.index != index || oldDelegate.progress != progress;
  }
}
