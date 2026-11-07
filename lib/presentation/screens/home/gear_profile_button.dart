part of '../home_screen.dart';

class _GearProfileButton extends ConsumerStatefulWidget {
  final String label;
  const _GearProfileButton({required this.label});

  @override
  ConsumerState<_GearProfileButton> createState() => _GearProfileButtonState();
}

class _GearProfileButtonState extends ConsumerState<_GearProfileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_reduceMotion) _controller.forward(from: 0.0);
    ProfileBottomSheet.show(context, ref.read(authProvider));
  }

  @override
  Widget build(BuildContext context) {
    final photoURL = ref.watch(authProvider.select((a) => a.user?.photoURL));
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: () { Haptics.tap(); _onTap(); },
        child: SizedBox(
          width: 34,
          height: 34,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _GearBorderPainter(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  rotation: _controller.value * pi / 4,
                ),
                child: child,
              );
            },
            child: Center(
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.bgCard,
                backgroundImage: photoURL != null
                    ? ResizeImage(CachedNetworkImageProvider(photoURL),
                        width: imageCacheSize(context, 24))
                    : null,
                child: photoURL == null
                    ? Icon(Icons.person,
                        size: 14, color: AppColors.accent, semanticLabel: widget.label)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GearBorderPainter extends CustomPainter {
  final Color color;
  final double rotation;
  const _GearBorderPainter({required this.color, this.rotation = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 3.5;
    const teethCount = 8;
    const toothWidth = 0.28;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final path = Path();
    for (int i = 0; i < teethCount; i++) {
      final angle = (i / teethCount) * 2 * pi - pi / 2;
      final nextAngle = ((i + 1) / teethCount) * 2 * pi - pi / 2;
      final toothStart = angle - toothWidth / 2;
      final toothEnd = angle + toothWidth / 2;
      final gapStart = toothEnd;
      final gapEnd = nextAngle - toothWidth / 2;

      if (i == 0) {
        path.moveTo(
          center.dx + outerRadius * cos(toothStart),
          center.dy + outerRadius * sin(toothStart),
        );
      }
      path.arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        toothStart,
        toothEnd - toothStart,
        false,
      );
      path.lineTo(
        center.dx + innerRadius * cos(gapStart),
        center.dy + innerRadius * sin(gapStart),
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        gapStart,
        gapEnd - gapStart,
        false,
      );
      path.lineTo(
        center.dx + outerRadius * cos(gapEnd),
        center.dy + outerRadius * sin(gapEnd),
      );
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GearBorderPainter old) =>
      old.color != color || old.rotation != rotation;
}
