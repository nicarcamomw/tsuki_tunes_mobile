part of 'login_screen.dart';

class _CyberGoogleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool loginSuccess;
  final ValueListenable<double> timeListenable;
  final LocaleProvider locale;
  final AppStrings strings;

  const _CyberGoogleButton({
    required this.onPressed,
    required this.isLoading,
    required this.loginSuccess,
    required this.timeListenable,
    required this.locale,
    required this.strings,
  });

  @override
  State<_CyberGoogleButton> createState() => _CyberGoogleButtonState();
}

class _CyberGoogleButtonState extends State<_CyberGoogleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;
  Offset _tapEpicenter = Offset.zero;

  ui.Image? _oniImg;
  ui.Image? _hannyaImg;
  ui.Image? _tenguImg;
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadMaskImages();
  }

  Future<void> _loadMaskImages() async {
    try {
      final results = await Future.wait([
        _loadAsset('assets/images/oni.png'),
        _loadAsset('assets/images/hannya.png'),
        _loadAsset('assets/images/tengu.png'),
      ]);
      if (mounted) {
        setState(() {
          _oniImg = results[0];
          _hannyaImg = results[1];
          _tenguImg = results[2];
          _imagesLoaded = true;
        });
      }
    } catch (_) {
    }
  }

  Future<ui.Image> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 40,
      targetHeight: 40,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _oniImg?.dispose();
    _hannyaImg?.dispose();
    _tenguImg?.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isLoading || widget.loginSuccess) return;
    Haptics.tap();
    _tapEpicenter = details.localPosition;
    if (!reduceMotion(context)) _rippleController.forward(from: 0.0);
  }

  Future<void> _handleTap() async {
    if (widget.isLoading || widget.loginSuccess) return;
    await Future.delayed(const Duration(milliseconds: 70));
    if (mounted) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Container(
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2A0A0D),
                    Color(0xFF1A0608),
                    Color(0xFF250A0E),
                  ],
                ),
              ),
            ),

            if (_imagesLoaded)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: widget.timeListenable,
                      builder: (context, t, _) {
                        return CustomPaint(
                          painter: _ButtonMaskPainter(
                            time: t,
                            oni: _oniImg,
                            hannya: _hannyaImg,
                            tengu: _tenguImg,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, _) {
                      if (_rippleController.value == 0.0 ||
                          _rippleController.value == 1.0) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        painter: _ButtonShockwaveRipplePainter(
                          progress: _rippleController.value,
                          center: _tapEpicenter,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            Semantics(
              button: true,
              label: widget.strings.a11yLoginWithGoogle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTap: _handleTap,
              child: SizedBox(
                height: 54,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: widget.loginSuccess
                      ? Row(
                          key: const ValueKey('granted'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.strings.loginGranted,
                              style: widget.locale.getTextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        )
                      : widget.isLoading
                          ? Row(
                              key: const ValueKey('loading'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.strings.loginLoading,
                                  style: widget.locale.getTextStyle(
                                    fontSize: AppFontSize.bodyLg,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('idle'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(AppRadius.chip),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const CustomPaint(
                                    size: Size(16, 16),
                                    painter: _GoogleLogoPainter(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  widget.strings.loginGoogle,
                                  style: widget.locale.getTextStyle(
                                    fontSize: AppFontSize.bodyLg,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonMask {
  final double baseX;
  final double baseY;
  final double speed;
  final double size;
  final double maxOpacity;
  final String asset;

  const _ButtonMask({
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.size,
    required this.maxOpacity,
    required this.asset,
  });
}

const List<_ButtonMask> _buttonMasks = [
  _ButtonMask(
    baseX: 0.05,
    baseY: 0.15,
    speed: 0.24,
    size: 19.0,
    maxOpacity: 0.18,
    asset: 'assets/images/oni.png',
  ),
  _ButtonMask(
    baseX: 0.13,
    baseY: 0.65,
    speed: 0.18,
    size: 18.0,
    maxOpacity: 0.15,
    asset: 'assets/images/hannya.png',
  ),
  _ButtonMask(
    baseX: 0.21,
    baseY: 0.35,
    speed: 0.28,
    size: 20.0,
    maxOpacity: 0.18,
    asset: 'assets/images/tengu.png',
  ),
  _ButtonMask(
    baseX: 0.29,
    baseY: 0.85,
    speed: 0.20,
    size: 17.5,
    maxOpacity: 0.14,
    asset: 'assets/images/oni.png',
  ),
  _ButtonMask(
    baseX: 0.71,
    baseY: 0.45,
    speed: 0.22,
    size: 18.0,
    maxOpacity: 0.15,
    asset: 'assets/images/hannya.png',
  ),
  _ButtonMask(
    baseX: 0.79,
    baseY: 0.10,
    speed: 0.26,
    size: 20.0,
    maxOpacity: 0.18,
    asset: 'assets/images/tengu.png',
  ),
  _ButtonMask(
    baseX: 0.87,
    baseY: 0.75,
    speed: 0.17,
    size: 17.5,
    maxOpacity: 0.14,
    asset: 'assets/images/oni.png',
  ),
  _ButtonMask(
    baseX: 0.95,
    baseY: 0.30,
    speed: 0.25,
    size: 19.0,
    maxOpacity: 0.18,
    asset: 'assets/images/hannya.png',
  ),
];

class _ButtonMaskPainter extends CustomPainter {
  final double time;
  final ui.Image? oni;
  final ui.Image? hannya;
  final ui.Image? tengu;

  _ButtonMaskPainter({
    required this.time,
    required this.oni,
    required this.hannya,
    required this.tengu,
  });

  static final Paint _maskPaint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (oni == null && hannya == null && tengu == null) return;
    final w = size.width;
    final h = size.height;

    for (final mask in _buttonMasks) {
      ui.Image? img;
      if (mask.asset.contains('oni')) {
        img = oni;
      } else if (mask.asset.contains('hannya')) {
        img = hannya;
      } else if (mask.asset.contains('tengu')) {
        img = tengu;
      }
      if (img == null) continue;

      final rawY = (mask.baseY + (time * mask.speed * 0.35)) % 1.0;
      final edgeFade = sin(rawY * pi).clamp(0.0, 1.0);
      final opacity = (mask.maxOpacity * edgeFade).clamp(0.0, 1.0);
      if (opacity <= 0.01) continue;

      final posX = mask.baseX * (w - mask.size);
      final posY = (rawY * (h + mask.size)) - (mask.size * 0.5);

      _maskPaint.colorFilter = ColorFilter.mode(
        const Color(0xFF2B2F38).withValues(alpha: opacity),
        BlendMode.srcIn,
      );

      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromLTWH(posX, posY, mask.size, mask.size);
      canvas.drawImageRect(img, src, dst, _maskPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonMaskPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.oni != oni ||
      oldDelegate.hannya != hannya ||
      oldDelegate.tengu != tengu;
}

class _ButtonShockwaveRipplePainter extends CustomPainter {
  final double progress;
  final Offset center;

  const _ButtonShockwaveRipplePainter({
    required this.progress,
    required this.center,
  });

  static final Paint _fillPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  static final Paint _ringPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final epicenter = (center == Offset.zero)
        ? Offset(size.width * 0.5, size.height * 0.5)
        : center;

    final maxRadius = min(size.width, size.height) * 0.55;

    if (progress < 0.45) {
      final fillProg = progress / 0.45;
      final fillRadius = maxRadius * 0.25 * Curves.easeOutQuart.transform(fillProg);
      final fillAlpha = (1.0 - fillProg) * 0.22;

      _fillPaint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: fillAlpha * 2.5),
          Colors.white.withValues(alpha: fillAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: epicenter, radius: fillRadius));

      canvas.drawCircle(epicenter, fillRadius, _fillPaint);
    }

    const ringCount = 5;
    const ringDelay = 0.08;
    for (int i = 0; i < ringCount; i++) {
      final ringStart = i * ringDelay;
      if (progress <= ringStart) continue;

      final ringProgress = ((progress - ringStart) / (1.0 - ringStart)).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(ringProgress);
      final radius = maxRadius * eased;

      final fadeIn = (ringProgress * 6.0).clamp(0.0, 1.0);
      final fadeOut = (1.0 - ringProgress);
      final alpha = fadeIn * fadeOut;

      final thickness = (1.8 - i * 0.2) * fadeOut;
      final ringAlpha = alpha * (1.0 - i * 0.15);

      _ringPaint
        ..color = Colors.white.withValues(alpha: ringAlpha * 0.8)
        ..strokeWidth = thickness;
      canvas.drawCircle(epicenter, radius, _ringPaint);

      if (ringAlpha > 0.05) {
        _ringPaint
          ..color = AppColors.accent.withValues(alpha: ringAlpha * 0.3)
          ..strokeWidth = thickness + 3.0;
        canvas.drawCircle(epicenter, radius, _ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ButtonShockwaveRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center;
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static final Paint _logoPaint = Paint()
    ..color = AppColors.bgDeep
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final p = _logoPaint;

    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.57, 23.685, 10.87, 23.555, 10.2)
      ..lineTo(12.0, 10.2)
      ..lineTo(12.0, 14.71)
      ..lineTo(18.6, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.2, 18.39)
      ..lineTo(16.2, 21.44)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.745, 16.27, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, p);

    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12.0, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.1, 5.28, 14.27)
      ..lineTo(1.25, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, p);

    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.9, 12.78, 4.9, 12.0)
      ..cubicTo(4.9, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.18, 0.0, 9.99, 0.0, 12.0)
      ..cubicTo(0.0, 14.01, 0.45, 15.82, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, p);

    final redPath = Path()
      ..moveTo(12.0, 4.8)
      ..cubicTo(13.77, 4.8, 15.35, 5.41, 16.6, 6.6)
      ..lineTo(20.02, 3.18)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.8, 12.0, 4.8)
      ..close();
    canvas.drawPath(redPath, p);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
