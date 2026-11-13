part of '../wrapped_screen.dart';

// The stories' shared pieces: backdrop, tags, counters, covers.
class _BarFill extends StatelessWidget {
  final double value;
  const _BarFill({required this.value});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 6)],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shared pieces
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SlideContext {
  final WrappedData data;
  final LocaleProvider locale;
  final AppStrings strings;
  final String period;
  final bool monthly;
  final String previousLabel;

  const _SlideContext({
    required this.data,
    required this.locale,
    required this.strings,
    required this.period,
    required this.monthly,
    required this.previousLabel,
  });

  TextStyle text(double size,
          {FontWeight weight = FontWeight.w600,
          Color color = AppColors.textBright,
          double? spacing,
          double? height}) =>
      locale.getTextStyle(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: height);

  TextStyle kanji(double size, Color color) =>
      GoogleFonts.notoSansJp(fontSize: size, fontWeight: FontWeight.w900, color: color);
}

/// The look every slide shares: night background with a tint, an optional
/// blurred cover, a giant faint kanji, scanlines and room for the top bar.
class _Backdrop extends StatelessWidget {
  final GlobalKey shareKey;
  final Color tint;
  final String? coverUrl;
  final String? kanji;
  final Widget child;
  final bool center;

  const _Backdrop({
    required this.shareKey,
    required this.tint,
    required this.child,
    this.coverUrl,
    this.kanji,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: shareKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(tint, Colors.black, 0.55)!, const Color(0xFF0B0D13), Colors.black],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          if (coverUrl != null && coverUrl!.isNotEmpty)
            // P-03: its own layer (the story's text animates over it
            // without repainting the blur), and the image fades itself
            // instead of through an Opacity layer.
            RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: CachedNetworkImage(
                  imageUrl: coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: imageCacheSize(context, 120),
                  color: Colors.white.withValues(alpha: 0.35),
                  colorBlendMode: BlendMode.modulate,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (kanji != null)
            Positioned(
              right: -40,
              bottom: 40,
              child: Text(
                kanji!,
                style: GoogleFonts.notoSansJp(
                  fontSize: AppFontSize.mega * 5, // a watermark glyph, not text
                  fontWeight: FontWeight.w900,
                  color: tint.withValues(alpha: 0.07),
                  height: 1,
                ),
              ),
            ),
          const CustomPaint(painter: _Scanlines()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 76, 24, 28),
              child: center ? Center(child: child) : child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Scanlines extends CustomPainter {
  const _Scanlines();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.12);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Scanlines oldDelegate) => false;
}

/// Small spaced-out label with a red diamond.
class _Tag extends StatelessWidget {
  final _SlideContext c;
  final String text;
  final Color color;
  const _Tag(this.c, this.text, {this.color = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('◈', style: c.text(AppFontSize.caption, color: color)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: c.text(AppFontSize.body, weight: FontWeight.w800, color: color, spacing: 2.4)),
        ),
      ],
    );
  }
}

/// A number that counts up when the slide appears.
class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(_thousands(v.round()), style: style),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _Cover extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final bool glow;
  const _Cover(this.url, {required this.size, this.radius = AppRadius.card, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.55), blurRadius: 40, spreadRadius: 2),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: imageCacheSize(context, size),
                placeholder: (_, __) => Container(color: AppColors.bgHover),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.bgHover,
        child: Icon(Icons.music_note_rounded, color: AppColors.accent, size: size * 0.4),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Slides
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
