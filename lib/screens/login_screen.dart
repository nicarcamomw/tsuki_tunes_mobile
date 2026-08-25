import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

const _maskUrls = [
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef2_Diseno-sin-titulo-59.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef3_Diseno-sin-titulo-50.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef1_Diseno-sin-titulo-57.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef4_Diseno-sin-titulo-56.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef5_Diseno-sin-titulo-55.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ef0_Diseno-sin-titulo-53.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eef_Diseno-sin-titulo-58.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eee_Diseno-sin-titulo-52.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eed_Diseno-sin-titulo-54.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eec_Diseno-sin-titulo-51.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eeb_Diseno-sin-titulo-49.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6eea_Diseno-sin-titulo-48.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ee9_Diseno-sin-titulo-47.avif',
  'https://cdn.prod.website-files.com/681ac2f6b2ba54268c0e6e4e/681ac2f6b2ba54268c0e6ee8_Diseno-sin-titulo-46.avif',
];

class _FloatingMask {
  final double x;
  final double y;
  final double size;
  final int speedX;
  final int speedY;
  final double phase;
  final double amplitudeX;
  final double amplitudeY;
  final int imageIndex;

  const _FloatingMask({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.imageIndex,
  });
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final List<_FloatingMask> _masks;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _masks = _generateMasks();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  List<_FloatingMask> _generateMasks() {
    final random = Random(42);
    return List.generate(12, (i) {
      return _FloatingMask(
        x: random.nextDouble() * 0.7 + 0.05,
        y: random.nextDouble() * 0.5 + 0.05,
        size: random.nextDouble() * 30 + 55,
        speedX: random.nextInt(2) + 1,
        speedY: random.nextInt(2) + 1,
        phase: random.nextDouble() * 2 * pi,
        amplitudeX: random.nextDouble() * 10 + 5,
        amplitudeY: random.nextDouble() * 10 + 5,
        imageIndex: i % _maskUrls.length,
      );
    });
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al iniciar sesión',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const _GridPainter()),
          ),

          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, _) {
                final t = _floatController.value;
                return Stack(
                  children: _masks.map((mask) {
                    final dx =
                        sin(t * 2 * pi * mask.speedX + mask.phase) *
                        mask.amplitudeX;
                    final dy =
                        cos(t * 2 * pi * mask.speedY + mask.phase * 1.3) *
                        mask.amplitudeY;
                    return Positioned(
                      left: mask.x * screen.width,
                      top: mask.y * screen.height,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: _MaskWidget(
                          url: _maskUrls[mask.imageIndex],
                          size: mask.size,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgDeep.withValues(alpha: 0.1),
                    AppColors.bgDeep.withValues(alpha: 0.5),
                    AppColors.bgDeep.withValues(alpha: 0.92),
                    AppColors.bgDeep,
                  ],
                  stops: const [0.0, 0.4, 0.7, 0.85],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'METAWORKS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 4,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  Text(
                    'TSUKI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBright,
                      letterSpacing: 8,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'TUNES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                      letterSpacing: 8,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(width: 60, height: 2, color: AppColors.accent),
                  const SizedBox(height: 16),

                  Text(
                    'TU BIBLIOTECA MUSICAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),

                  const Spacer(flex: 2),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.accentDim,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4285F4),
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'CONTINUAR CON GOOGLE',
                                  style: GoogleFonts.silkscreen(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'VERSION: 2.0.0-RC.1',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskWidget extends StatelessWidget {
  final String url;
  final double size;

  const _MaskWidget({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.bgMid),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.bgMid,
            child: Icon(
              Icons.masks_outlined,
              color: AppColors.textMuted,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 60.0;

    final linePaint =
        Paint()
          ..color = const Color(0x0DFFFFFF)
          ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final crossPaint =
        Paint()
          ..color = const Color(0x1AFF1919)
          ..strokeWidth = 1;
    const crossSize = 4.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(
          Offset(x - crossSize, y),
          Offset(x + crossSize, y),
          crossPaint,
        );
        canvas.drawLine(
          Offset(x, y - crossSize),
          Offset(x, y + crossSize),
          crossPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
