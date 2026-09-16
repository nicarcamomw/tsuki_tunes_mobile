import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// CyberOrb: Ultra-Premium 3D Glassmorphic Holographic Plasma Sphere
/// Powered by continuous microsecond Ticker for 100% uninterrupted, infinite,
/// perfectly smooth 120 FPS animation with ZERO cut-offs, resets, or seams.
class CyberOrb extends StatefulWidget {
  final double size;
  final Widget? centerChild;
  final bool showOuterRings;
  final bool showCornerBrackets;

  const CyberOrb({
    super.key,
    this.size = 180,
    this.centerChild,
    this.showOuterRings = true,
    this.showCornerBrackets = false,
  });

  @override
  State<CyberOrb> createState() => _CyberOrbState();
}

class _CyberOrbState extends State<CyberOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    // Continuous monotonic ticker: NEVER resets, NEVER wraps, ZERO cut-offs
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _time = elapsed.inMicroseconds / 1000000.0;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = widget.size;
    final totalSize = widget.showOuterRings ? orbSize * 1.55 : orbSize * 1.15;
    final t = _time;

    // Smooth continuous floating motion
    final floatDy = sin(t * 1.2) * 3.5;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Transform.translate(
        offset: Offset(0, floatDy),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ambient Background Crimson Nebula Glow
            _buildAmbientGlow(orbSize, t),

            // 2. High-Tech Cyberpunk HUD Surroundings (Arcs, Ticks, Compass & Brackets)
            if (widget.showOuterRings)
              CustomPaint(
                size: Size(totalSize, totalSize),
                painter: _CyberHudSurroundPainter(
                  time: t,
                  orbRadius: orbSize / 2,
                  showCornerBrackets: widget.showCornerBrackets,
                ),
              ),

            // 3. Technical Cyberpunk HUD Corner Labels
            if (widget.showOuterRings && widget.showCornerBrackets)
              _buildHudCornerLabels(totalSize),

            // 4. The 3D Glass Sphere Body with Continuous Deep Red Plasma Ribbons
            Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // Intense Core Crimson Red Glow
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    blurRadius: 46,
                    spreadRadius: 6,
                  ),
                  // Blood-Red Secondary Glow
                  BoxShadow(
                    color: const Color(0xFFFF0D3A).withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: -2,
                  ),
                  // Deep Ruby Outer Atmosphere
                  BoxShadow(
                    color: const Color(0xFF660010).withValues(alpha: 0.40),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    // Core 3D Liquid Crimson Plasma Painter (Continuous Ticker)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CrimsonOrbFluidPainter(time: t),
                      ),
                    ),

                    // Optional Center Hologram (Tengu/Oni mask)
                    if (widget.centerChild != null)
                      Center(
                        child: widget.centerChild!,
                      ),

                    // Top Layer: 3D Curved Glass Surface Specular Reflections
                    Positioned.fill(
                      child: CustomPaint(
                        painter: const _OrbGlassReflectionPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Outer Fine Glass Rim / High-Voltage Crimson Fresnel Ring
            IgnorePointer(
              child: Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(double orbSize, double t) {
    final pulse = (sin(t * 1.5) + 1.0) / 2.0;
    final glowRadius = orbSize * (1.20 + 0.15 * pulse);

    return Container(
      width: glowRadius,
      height: glowRadius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.45 + 0.12 * pulse),
            const Color(0xFFC40026).withValues(alpha: 0.28 + 0.08 * pulse),
            const Color(0xFF55000C).withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 0.72, 1.0],
        ),
      ),
    );
  }

  Widget _buildHudCornerLabels(double size) {
    const pad = 12.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top-Left Tech Tag
          Positioned(
            top: pad,
            left: pad,
            child: Text(
              'SYS // TS-01',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.accent.withValues(alpha: 0.75),
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Top-Right Tech Tag
          Positioned(
            top: pad,
            right: pad,
            child: Text(
              'ORB.CORE: 432HZ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.0,
              ),
            ),
          ),
          // Bottom-Left Tech Tag
          Positioned(
            bottom: pad,
            left: pad,
            child: Text(
              'RADIAL: LOCK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.0,
              ),
            ),
          ),
          // Bottom-Right Tech Tag
          Positioned(
            bottom: pad,
            right: pad,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'SYNC: 99.8%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seamless Continuous 3D Fluid Crimson Painter
/// Pure, deep cyber reds, hot flame orange-reds, and ruby tones with 0 discontinuities.
class _CrimsonOrbFluidPainter extends CustomPainter {
  final double time;

  _CrimsonOrbFluidPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dark Obsidian & Crimson Glass Base
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 1.15,
        colors: const [
          Color(0xFF380710), // Deep ruby-black highlight
          Color(0xFF180509), // Obsidian crimson shadow
          Color(0xFF080204), // Pure deep abyss
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, basePaint);

    // 2. Primary Toroidal Plasma Band: Hot Neon Crimson & Fiery Scarlet
    _drawClosedToroidalRibbon(
      canvas: canvas,
      center: center,
      baseRadius: radius * 0.64,
      waveAmp: 0.22,
      waveFreq: 3,
      rotAngle: time * 0.45,
      tilt: 0.60,
      thickness: radius * 0.46,
      colors: [
        const Color(0xFFFF1919),
        const Color(0xFFFF3B30),
        const Color(0xFFB8001F),
      ],
      blurSigma: 14,
    );

    // 3. Secondary Toroidal Plasma Band: Dark Blood Red & Deep Wine
    _drawClosedToroidalRibbon(
      canvas: canvas,
      center: center,
      baseRadius: radius * 0.58,
      waveAmp: 0.18,
      waveFreq: 2,
      rotAngle: -time * 0.35 + pi * 0.5,
      tilt: -0.85,
      thickness: radius * 0.42,
      colors: [
        const Color(0xFFFF0D3A),
        const Color(0xFFD90429),
        const Color(0xFF59000E),
      ],
      blurSigma: 12,
    );

    // 4. Tertiary High-Intensity Core Ribbon: Blazing Red & White-Hot Flash
    _drawClosedToroidalRibbon(
      canvas: canvas,
      center: center,
      baseRadius: radius * 0.68,
      waveAmp: 0.15,
      waveFreq: 4,
      rotAngle: time * 0.60 + pi * 1.2,
      tilt: 1.15,
      thickness: radius * 0.28,
      colors: [
        const Color(0xFFFF6666),
        const Color(0xFFFF1919),
        const Color(0xFFFF1919).withValues(alpha: 0.2),
      ],
      blurSigma: 8,
    );

    // 5. Central Glowing Fusion Core (White-hot crimson core)
    final corePulse = (sin(time * 1.8) + 1.0) / 2.0;
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85 + 0.15 * corePulse),
          const Color(0xFFFF3355).withValues(alpha: 0.70),
          const Color(0xFFFF1919).withValues(alpha: 0.30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.50));

    canvas.drawCircle(center, radius * 0.42, corePaint);

    // 6. Volumetric 3D Spherical Edge Shadow (Vignette)
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.1, -0.1),
        radius: 1.05,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.18),
          Colors.black.withValues(alpha: 0.85),
        ],
        stops: const [0.58, 0.80, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, vignettePaint);
  }

  void _drawClosedToroidalRibbon({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double waveAmp,
    required int waveFreq,
    required double rotAngle,
    required double tilt,
    required double thickness,
    required List<Color> colors,
    required double blurSigma,
  }) {
    final path = Path();
    const steps = 72;
    final points = <Offset>[];

    for (int i = 0; i <= steps; i++) {
      final theta = i * 2 * pi / steps;

      final rWave = baseRadius * (1.0 + waveAmp * sin(waveFreq * theta + time * 0.5));

      final x0 = rWave * cos(theta);
      final y0 = rWave * sin(theta);

      final x1 = x0 * cos(rotAngle) - y0 * sin(rotAngle) * cos(tilt);
      final y1 = x0 * sin(rotAngle) + y0 * cos(rotAngle) * cos(tilt);

      points.add(Offset(center.dx + x1, center.dy + y1));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.close();

    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma)
      ..shader = LinearGradient(
        begin: Alignment(-cos(rotAngle), -sin(rotAngle)),
        end: Alignment(cos(rotAngle), sin(rotAngle)),
        colors: colors,
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.3));

    canvas.drawPath(path, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant _CrimsonOrbFluidPainter oldDelegate) =>
      oldDelegate.time != time;
}

/// Custom painter that creates realistic 3D curved glass highlights & reflections
class _OrbGlassReflectionPainter extends CustomPainter {
  const _OrbGlassReflectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Primary Top-Left Crescent Specular Highlight
    final highlightPath = Path();
    highlightPath.moveTo(w * 0.16, h * 0.38);
    highlightPath.quadraticBezierTo(w * 0.20, h * 0.14, w * 0.48, h * 0.11);
    highlightPath.quadraticBezierTo(w * 0.28, h * 0.18, w * 0.20, h * 0.34);
    highlightPath.close();

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawPath(highlightPath, highlightPaint);

    // 2. Secondary Top Oval Soft Reflection
    final topOvalRect = Rect.fromCenter(
      center: Offset(w * 0.38, h * 0.17),
      width: w * 0.26,
      height: h * 0.08,
    );
    final topOvalPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.50),
          Colors.transparent,
        ],
      ).createShader(topOvalRect);

    canvas.save();
    canvas.translate(w * 0.38, h * 0.17);
    canvas.rotate(-pi * 0.16);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.24, height: h * 0.07), topOvalPaint);
    canvas.restore();

    // 3. Subtle bottom-right rim bounce light (Refraction in red)
    final bouncePath = Path();
    bouncePath.moveTo(w * 0.62, h * 0.89);
    bouncePath.quadraticBezierTo(w * 0.84, h * 0.83, w * 0.89, h * 0.62);

    final bouncePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          const Color(0xFFFF1919).withValues(alpha: 0.55),
          const Color(0xFFFF4D00).withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(bouncePath, bouncePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbGlassReflectionPainter oldDelegate) => false;
}

/// Cyberpunk HUD Surround Painter:
/// Paints rotating telemetry arcs, radar ticks, compass crosshairs, and 4 corner target brackets.
class _CyberHudSurroundPainter extends CustomPainter {
  final double time;
  final double orbRadius;
  final bool showCornerBrackets;

  _CyberHudSurroundPainter({
    required this.time,
    required this.orbRadius,
    this.showCornerBrackets = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Four Cyberpunk Corner Brackets (Target Lock L-shapes)
    if (showCornerBrackets) {
      final bracketPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.70)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      const bPad = 8.0;
      const bLen = 16.0;

      // Top-Left L
      canvas.drawLine(const Offset(bPad, bPad + bLen), const Offset(bPad, bPad), bracketPaint);
      canvas.drawLine(const Offset(bPad, bPad), const Offset(bPad + bLen, bPad), bracketPaint);

      // Top-Right L
      canvas.drawLine(Offset(size.width - bPad - bLen, bPad), Offset(size.width - bPad, bPad), bracketPaint);
      canvas.drawLine(Offset(size.width - bPad, bPad), Offset(size.width - bPad, bPad + bLen), bracketPaint);

      // Bottom-Left L
      canvas.drawLine(Offset(bPad, size.height - bPad - bLen), Offset(bPad, size.height - bPad), bracketPaint);
      canvas.drawLine(Offset(bPad, size.height - bPad), Offset(bPad + bLen, size.height - bPad), bracketPaint);

      // Bottom-Right L
      canvas.drawLine(Offset(size.width - bPad - bLen, size.height - bPad), Offset(size.width - bPad, size.height - bPad), bracketPaint);
      canvas.drawLine(Offset(size.width - bPad, size.height - bPad), Offset(size.width - bPad, size.height - bPad - bLen), bracketPaint);
    }

    // 2. Rotating Segmented Cyber Arcs (Clockwise)
    final arcRadius = orbRadius + 14.0;
    final arcPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const arcCount = 3;
    final sweepAngle = (2 * pi / arcCount) * 0.65;
    for (int i = 0; i < arcCount; i++) {
      final startAngle = (i * (2 * pi / arcCount)) + (time * 0.35);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // 3. Counter-Rotating Inner Radar Track (Dashed Micro Ring)
    final innerTrackRadius = orbRadius + 6.0;
    final innerTrackPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dotCount = 24;
    for (int i = 0; i < dotCount; i++) {
      if (i % 2 == 0) continue;
      final angle = (i * (2 * pi / dotCount)) - (time * 0.20);
      final p1 = Offset(center.dx + cos(angle) * (innerTrackRadius - 2), center.dy + sin(angle) * (innerTrackRadius - 2));
      final p2 = Offset(center.dx + cos(angle) * (innerTrackRadius + 2), center.dy + sin(angle) * (innerTrackRadius + 2));
      canvas.drawLine(p1, p2, innerTrackPaint);
    }

    // 4. Cardinal Compass Crosshairs (0°, 90°, 180°, 270°)
    final crosshairPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final outerMarkerRadius = orbRadius + 22.0;
    const cardinalAngles = [0.0, pi / 2, pi, 3 * pi / 2];

    for (final angle in cardinalAngles) {
      final pStart = Offset(center.dx + cos(angle) * (outerMarkerRadius - 4), center.dy + sin(angle) * (outerMarkerRadius - 4));
      final pEnd = Offset(center.dx + cos(angle) * (outerMarkerRadius + 4), center.dy + sin(angle) * (outerMarkerRadius + 4));
      canvas.drawLine(pStart, pEnd, crosshairPaint);
    }

    // 5. Fine Outer Hairline Enclosure Ring
    final enclosurePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, outerMarkerRadius + 2.0, enclosurePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberHudSurroundPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.orbRadius != orbRadius ||
      oldDelegate.showCornerBrackets != showCornerBrackets;
}
