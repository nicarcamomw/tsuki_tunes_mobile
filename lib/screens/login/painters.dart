part of 'login_screen.dart';

class _RadialSoundWavePainter extends CustomPainter {
  final double time;

  const _RadialSoundWavePainter({required this.time});

  static final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;

  static final Paint _innerGlowRing = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.09)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  static final Paint _ribbonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..color = AppColors.accent.withValues(alpha: 0.18);

  static final Paint _reflectionPaint = Paint()..strokeCap = StrokeCap.round;

  static final Paint _glowPaint = Paint()
    ..strokeCap = StrokeCap.round;

  static final Paint _corePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const barCount = 48;

    final bassPulse = pow(max(0.0, sin(time * 3.2)), 4.0) * 2.2;
    final baseRadius = 76.0 + bassPulse;

    _trackPaint.color = AppColors.accent.withValues(alpha: 0.22 + (bassPulse * 0.08));
    canvas.drawCircle(center, baseRadius, _trackPaint);
    canvas.drawCircle(center, baseRadius - 2.5, _innerGlowRing);

    final ribbonPath = Path();
    const ribbonSteps = 120;
    for (int s = 0; s <= ribbonSteps; s++) {
      final tStep = (s / ribbonSteps) * 2 * pi;
      final wA = sin((time * 3.2) + (tStep * 3.0));
      final wB = cos((-time * 4.2) + (tStep * 2.0));
      final rDelta = (wA * 0.55 + wB * 0.45) * 6.5;
      final rRibbon = baseRadius + 10.0 + rDelta;

      final rx = center.dx + cos(tStep) * rRibbon;
      final ry = center.dy + sin(tStep) * rRibbon;

      if (s == 0) {
        ribbonPath.moveTo(rx, ry);
      } else {
        ribbonPath.lineTo(rx, ry);
      }
    }
    ribbonPath.close();
    canvas.drawPath(ribbonPath, _ribbonPaint);

    for (int i = 0; i < barCount; i++) {
      final theta = (i / barCount) * 2 * pi;
      final isPrimary = (i % 2 == 0);

      final wave1 = sin((time * 3.6) + (theta * 3.0));
      final wave2 = cos((-time * 4.6) + (theta * 2.0));
      final wave3 = sin((time * 1.8) - (theta * 4.0));
      final wave4 = cos((time * 6.0) + (theta * 1.0)) * 0.15;

      final raw = ((wave1 * 0.40 + wave2 * 0.36 + wave3 * 0.24 + wave4) + 1.0) / 2.0;

      final maxLen = isPrimary ? 22.0 : 15.0;
      final minLen = isPrimary ? 4.5 : 3.0;
      final barLen = minLen + (raw.clamp(0.0, 1.0) * (maxLen - minLen));

      final cosT = cos(theta);
      final sinT = sin(theta);

      final pStart = Offset(
        center.dx + cosT * baseRadius,
        center.dy + sinT * baseRadius,
      );
      final pEnd = Offset(
        center.dx + cosT * (baseRadius + barLen),
        center.dy + sinT * (baseRadius + barLen),
      );

      final pInnerEnd = Offset(
        center.dx + cosT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
        center.dy + sinT * (baseRadius - (isPrimary ? 3.0 : 1.8)),
      );

      final barThickness = isPrimary ? 3.0 : 2.0;

      _reflectionPaint
        ..color = AppColors.accent.withValues(alpha: 0.16)
        ..strokeWidth = barThickness * 0.8;
      canvas.drawLine(pStart, pInnerEnd, _reflectionPaint);

      _glowPaint
        ..color = AppColors.accent.withValues(alpha: isPrimary ? 0.35 : 0.20)
        ..strokeWidth = barThickness + 4.0;
      canvas.drawLine(pStart, pEnd, _glowPaint);

      _corePaint
        ..strokeWidth = barThickness
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF55000A),
            AppColors.accent,
            Color(0xFFFF2B40),
            Color(0xFFFF485B),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        ).createShader(Rect.fromPoints(pStart, pEnd));
      canvas.drawLine(pStart, pEnd, _corePaint);

      if (raw > 0.65 && isPrimary) {
        final highlightFraction = ((raw - 0.65) / 0.35).clamp(0.0, 1.0);
        final pMid = Offset.lerp(pStart, pEnd, 0.55)!;
        _highlightPaint.color = const Color(0xFFFF6677).withValues(alpha: 0.70 * highlightFraction);
        canvas.drawLine(pMid, pEnd, _highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialSoundWavePainter oldDelegate) =>
      oldDelegate.time != time;
}

class _PlasmaGlowPainter extends CustomPainter {
  final double time;
  const _PlasmaGlowPainter({required this.time});

  static final Paint _glowPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final breath = sin(time * 1.8);

    _glowPaint.shader = RadialGradient(
      radius: 0.52 + 0.12 * breath,
      colors: [
        AppColors.accent.withValues(alpha: 0.26 + 0.08 * breath),
        AppColors.accent.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, _glowPaint);
  }

  @override
  bool shouldRepaint(covariant _PlasmaGlowPainter old) => old.time != time;
}

class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter();

  static final Paint _linePaint = Paint()
    ..color = const Color(0x06FFFFFF)
    ..strokeWidth = 0.5;

  static final Paint _crossPaint = Paint()
    ..color = AppColors.accent.withValues(alpha: 0.13)
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 44.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _linePaint);
    }

    const crossSize = 3.0;
    for (double x = spacing; x < size.width; x += spacing * 2) {
      for (double y = spacing; y < size.height; y += spacing * 2) {
        canvas.drawLine(Offset(x - crossSize, y), Offset(x + crossSize, y), _crossPaint);
        canvas.drawLine(Offset(x, y - crossSize), Offset(x, y + crossSize), _crossPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) => false;
}

class _CyberParticle {
  final double baseX;
  final double baseY;
  final double size;
  final double speed;
  final double maxOpacity;
  final double phase;
  final bool isCrimson;

  const _CyberParticle({
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.speed,
    required this.maxOpacity,
    required this.phase,
    required this.isCrimson,
  });
}

class _CyberParticlesPainter extends CustomPainter {
  final List<_CyberParticle> particles;
  final double time;

  _CyberParticlesPainter({
    required this.particles,
    required this.time,
  });

  static final Paint _haloPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  static final Paint _corePaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final rawY = (p.baseY - (time * p.speed * 0.15)) % 1.0;
      final currentY = rawY < 0 ? rawY + 1.0 : rawY;
      final edgeFade = sin(currentY * pi).clamp(0.0, 1.0);

      final swayX = (p.baseX + sin(time * 0.8 + p.phase) * 0.04) % 1.0;

      final px = swayX * size.width;
      final py = currentY * size.height;

      final flicker = 0.7 + 0.3 * sin(time * 2.5 + p.phase);
      final finalAlpha = (p.maxOpacity * edgeFade * flicker).clamp(0.0, 1.0);

      final color = p.isCrimson
          ? AppColors.accent.withValues(alpha: finalAlpha)
          : const Color(0xFFFF3344).withValues(alpha: finalAlpha * 0.9);

      final pos = Offset(px, py);

      _haloPaint.color = color.withValues(alpha: finalAlpha * 0.35);
      canvas.drawCircle(pos, p.size * 2.0, _haloPaint);

      _corePaint.color = color;
      canvas.drawCircle(pos, p.size / 2, _corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberParticlesPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _FilamentVector {
  final double cosVal;
  final double sinVal;
  final double innerOffset;
  final double outerOffset;

  const _FilamentVector({
    required this.cosVal,
    required this.sinVal,
    required this.innerOffset,
    required this.outerOffset,
  });
}

class _ShockwavePainter extends CustomPainter {
  final double progress;
  final Offset epicenter;

  const _ShockwavePainter({
    required this.progress,
    required this.epicenter,
  });

  static final Paint _flashPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _discPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _filamentPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  static final Paint _outerGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;
  static final Paint _coreRingPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _echoPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  static final Paint _subPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _overlayPaint = Paint()..style = PaintingStyle.fill;

  static final List<_FilamentVector> _filaments = List.generate(18, (i) {
    final angle = (i / 18.0) * 2 * pi + (sin(i * 1.7) * 0.15);
    return _FilamentVector(
      cosVal: cos(angle),
      sinVal: sin(angle),
      innerOffset: 16.0 + (i % 3) * 8.0,
      outerOffset: 12.0 + (i % 4) * 6.0,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final maxDistX = max(epicenter.dx, size.width - epicenter.dx);
    final maxDistY = max(epicenter.dy, size.height - epicenter.dy);
    final maxRadius = sqrt(maxDistX * maxDistX + maxDistY * maxDistY) * 1.08;

    final curvedProgress = Curves.easeOutCubic.transform(progress);
    final primaryRadius = 69.0 + (maxRadius - 69.0) * curvedProgress;

    if (progress < 0.45) {
      final flashProg = progress / 0.45;
      final flashRadius = 35.0 + 130.0 * Curves.easeOutQuad.transform(flashProg);
      final flashAlpha = (1.0 - flashProg).clamp(0.0, 1.0);

      _flashPaint.shader = RadialGradient(
        colors: [
          const Color(0xFFFF2B2B).withValues(alpha: flashAlpha * 0.95),
          AppColors.accent.withValues(alpha: flashAlpha * 0.70),
          const Color(0xFF8A0005).withValues(alpha: flashAlpha * 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: flashRadius));

      canvas.drawCircle(epicenter, flashRadius, _flashPaint);
    }

    if (primaryRadius > 20) {
      final discAlpha = (1.0 - (progress * 0.75)).clamp(0.0, 1.0);
      _discPaint.shader = RadialGradient(
        colors: [
          Colors.transparent,
          AppColors.accent.withValues(alpha: 0.04 * discAlpha),
          AppColors.accent.withValues(alpha: 0.18 * discAlpha),
          AppColors.accent.withValues(alpha: 0.35 * discAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 0.88, 0.97, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: primaryRadius));

      canvas.drawCircle(epicenter, primaryRadius, _discPaint);
    }

    if (progress < 0.85) {
      final filamentAlpha = (1.0 - (progress / 0.85)).clamp(0.0, 1.0) * 0.55;
      _filamentPaint.color = AppColors.accent.withValues(alpha: filamentAlpha);

      for (int i = 0; i < 18; i++) {
        final f = _filaments[i];
        final rInner = max(0.0, primaryRadius - f.innerOffset);
        final rOuter = primaryRadius + f.outerOffset;
        canvas.drawLine(
          Offset(epicenter.dx + f.cosVal * rInner, epicenter.dy + f.sinVal * rInner),
          Offset(epicenter.dx + f.cosVal * rOuter, epicenter.dy + f.sinVal * rOuter),
          _filamentPaint,
        );
      }
    }

    final waveAlpha = (1.0 - (progress * 0.35)).clamp(0.0, 1.0);

    _outerGlowPaint.color = AppColors.accent.withValues(alpha: 0.40 * waveAlpha);
    canvas.drawCircle(epicenter, primaryRadius, _outerGlowPaint);

    final strokeWidth = max(1.8, 4.2 * (1.0 - progress * 0.45));
    _coreRingPaint
      ..color = const Color(0xFFFF4040).withValues(alpha: 0.95 * waveAlpha)
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(epicenter, primaryRadius, _coreRingPaint);

    if (progress > 0.08) {
      final echoProg = Curves.easeOutCubic.transform(
        ((progress - 0.08) / 0.92).clamp(0.0, 1.0),
      );
      final echoRadius = 69.0 + (maxRadius - 69.0) * echoProg;
      final echoAlpha = (1.0 - echoProg).clamp(0.0, 1.0) * 0.65;

      _echoPaint.color = AppColors.accent.withValues(alpha: echoAlpha);
      canvas.drawCircle(epicenter, echoRadius, _echoPaint);
    }

    if (progress > 0.18) {
      final subProg = Curves.easeOutCubic.transform(
        ((progress - 0.18) / 0.82).clamp(0.0, 1.0),
      );
      final subRadius = 69.0 + (maxRadius - 69.0) * subProg;
      final subAlpha = (1.0 - subProg).clamp(0.0, 1.0) * 0.38;

      _subPaint.color = AppColors.accent.withValues(alpha: subAlpha);
      canvas.drawCircle(epicenter, subRadius, _subPaint);
    }

    if (progress > 0.50) {
      final fadeProg = Curves.easeInQuad.transform(
        ((progress - 0.50) / 0.50).clamp(0.0, 1.0),
      );
      _overlayPaint.color = const Color(0xFF0F0203).withValues(alpha: fadeProg);
      canvas.drawPaint(_overlayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.epicenter != epicenter;
  }
}

class _PulseDotPainter extends CustomPainter {
  final double time;
  const _PulseDotPainter({required this.time});

  static final Paint _dotPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = sin(time * 2.5) * 0.5 + 0.5;
    _glowPaint.color = AppColors.accent.withValues(alpha: 0.25 + 0.25 * pulse);
    canvas.drawCircle(center, 5.0, _glowPaint);
    _dotPaint.color = AppColors.accent;
    canvas.drawCircle(center, 3.0, _dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseDotPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _FooterDot extends StatelessWidget {
  final Color color;
  const _FooterDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.7),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
