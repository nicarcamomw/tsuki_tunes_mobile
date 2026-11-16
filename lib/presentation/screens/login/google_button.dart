part of 'login_screen.dart';

/// Google's sign-in button, as its brand guide asks: a light pill, the
/// four-colour G, "Continue with Google" in Roboto Medium, dark text.
/// Pressed it springs a little; busy, it says so and waits; disabled
/// (offline, too many tries), it fades.
class _GoogleButton extends StatefulWidget {
  const _GoogleButton({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      // The tap TalkBack performs (the InkWell's own is hidden with it).
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? 0.45 : 1,
        duration: AppMotion.fast,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: AppMotion.micro,
          curve: AppMotion.move,
          child: Material(
            color: Colors.white,
            shape: const StadiumBorder(side: BorderSide(color: AppColors.googleStroke)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (down) => setState(() => _down = down && enabled),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.googleText),
                      )
                    else
                      const CustomPaint(size: Size.square(20), painter: _GoogleG()),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: AppFonts.roboto, 
                          fontSize: AppFontSize.titleLg,
                          fontWeight: FontWeight.w500,
                          color: AppColors.googleText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's "G": four arcs (red, yellow, green, blue) and the blue bar.
class _GoogleG extends CustomPainter {
  const _GoogleG();

  static const _blue = AppColors.googleBlue;
  static const _red = AppColors.googleRed;
  static const _yellow = AppColors.googleYellow;
  static const _green = AppColors.googleGreen;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final c = size.center(Offset.zero);
    final r = s / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    double deg(double d) => d * math.pi / 180;
    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color;
    canvas
      ..drawArc(rect, deg(-45), deg(-115), false, arc(_red)) // over the top
      ..drawArc(rect, deg(-160), deg(-60), false, arc(_yellow)) // the left
      ..drawArc(rect, deg(140), deg(-100), false, arc(_green)) // the bottom
      ..drawArc(rect, deg(40), deg(-40), false, arc(_blue)) // the right
      ..drawRect(Rect.fromLTRB(c.dx, c.dy - stroke / 2, c.dx + r + stroke / 2, c.dy + stroke / 2), Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleG old) => false;
}
