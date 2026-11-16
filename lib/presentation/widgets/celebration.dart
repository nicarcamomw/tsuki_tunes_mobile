import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/locale_provider.dart';
import 'connection_notice.dart';
import 'frosted_glass.dart';
import 'motion.dart';
import 'player_tint.dart';

/// How long a celebration stays: long enough to read [text] (about a word a
/// quarter second), doubled when TalkBack reads it aloud.
Duration readingTime(String text, {bool talkBack = false}) {
  final ms = (3800 + text.length * 55).clamp(4500, 9000);
  return Duration(milliseconds: talkBack ? ms * 2 : ms);
}

/// A celebration at the top of the app (a mask woken, a level reached): a
/// capsule of liquid glass with a rim and a glow in [color], sliding in.
///
/// - Stays [readingTime] for what it says; a finger held on it pauses it.
/// - Tap opens what it's about ([onOpen]); a swipe up sends it away.
/// - Below the connection pill when that's showing.
/// - [shimmer]: a sheen crosses [leading] once (rarer things).
class CelebrationBanner extends StatefulWidget {
  const CelebrationBanner({
    super.key,
    required this.color,
    required this.leading,
    required this.overline,
    required this.title,
    required this.locale,
    required this.onDone,
    this.details = const [],
    this.readText = '',
    this.onOpen,
    this.shimmer = false,
  });

  final Color color;
  final Widget leading;
  final String overline;
  final String title;
  final List<Widget> details;

  /// The rest of what it says (for its reading time and TalkBack).
  final String readText;
  final LocaleProvider locale;
  final VoidCallback? onOpen;

  /// Gone: after it slid away, by itself or sent.
  final VoidCallback onDone;
  final bool shimmer;

  @override
  State<CelebrationBanner> createState() => _CelebrationBannerState();
}

class _CelebrationBannerState extends State<CelebrationBanner> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: AppMotion.slow);
  late final AnimationController _sheen = AnimationController(vsync: this, duration: AppMotion.revealLong);
  Timer? _leave;
  bool _closing = false;
  bool _held = false;

  Duration get _stay =>
      readingTime('${widget.title} ${widget.readText}', talkBack: MediaQuery.maybeAccessibleNavigationOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enter.isDismissed) return;
    if (reduceMotion(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
      if (widget.shimmer) {
        unawaited(
          Future<void>.delayed(AppMotion.slow, () {
            if (mounted) _sheen.forward();
          }),
        );
      }
    }
    _leave = Timer(_stay, _close);
  }

  void _hold(bool held) {
    if (_closing || held == _held) return;
    _held = held;
    _leave?.cancel();
    // Let go: a moment more to finish reading.
    if (!held) _leave = Timer(const Duration(milliseconds: 2500), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _leave?.cancel();
    if (reduceMotion(context)) {
      _enter.value = 0;
    } else {
      await _enter.reverse();
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _leave?.cancel();
    _enter.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final color = widget.color;
    final slide = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    // Over the whole app, above its pages: its own (clear) material for
    // the text.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: ConnectionNotice.visible,
          builder: (context, pill, child) => AnimatedPadding(
            duration: AppMotion.normal,
            curve: AppMotion.move,
            padding: EdgeInsets.fromLTRB(12, 8 + (pill ? ConnectionNotice.clearance : 0), 12, 0),
            child: child,
          ),
          child: AnimatedBuilder(
            animation: _enter,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (1 - slide.value) * -150),
              child: Opacity(opacity: _enter.value.clamp(0.0, 1.0), child: child),
            ),
            child: Semantics(
              liveRegion: true,
              button: widget.onOpen != null,
              label: '${widget.overline}: ${widget.title}. ${widget.readText}',
              child: ExcludeSemantics(
                child: Listener(
                  onPointerDown: (_) => _hold(true),
                  onPointerUp: (_) => _hold(false),
                  onPointerCancel: (_) => _hold(false),
                  child: GestureDetector(
                    onTap: widget.onOpen == null
                        ? null
                        : () {
                            unawaited(_close());
                            widget.onOpen!();
                          },
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < 0) unawaited(_close());
                    },
                    child: FrostedGlass(
                      color: AppColors.inkPanel,
                      fill: AppGlass.fill,
                      borderRadius: BorderRadius.circular(AppRadius.sheet),
                      border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
                      shadowColor: color.withValues(alpha: 0.32),
                      child: DecoratedBox(
                        // The colour seeps in from the side of its picture.
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
                            stops: const [0, 0.6],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: widget.shimmer ? _Sheen(progress: _sheen, child: widget.leading) : widget.leading,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.overline,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: locale.getTextStyle(
                                        fontSize: AppFontSize.micro,
                                        fontWeight: FontWeight.w900,
                                        // Its colour, lifted where it wouldn't read.
                                        color: readableTint(color),
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: locale.getTextStyle(
                                        fontSize: AppFontSize.titleLg,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textBright,
                                      ),
                                    ),
                                    ...widget.details,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheen of light crossing [child] once, as [progress] runs.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.progress, required this.child});

  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) {
      final t = progress.value;
      if (t <= 0 || t >= 1) return child!;
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0)],
          stops: [(t - 0.1).clamp(0.0, 1.0), t, (t + 0.1).clamp(0.0, 1.0)],
        ).createShader(bounds),
        child: child,
      );
    },
  );
}

/// Rays of light bursting out behind something as it appears, as [t] goes
/// from 0 to 1: lines that fly out and fade, a ring that widens.
class BurstPainter extends CustomPainter {
  BurstPainter(this.t, this.color, {this.rays = 12, this.reach = 1});

  final double t;
  final Color color;
  final int rays;

  /// How far the rays fly, in the painter's half-widths.
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55 * fade)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays + t * 0.6;
      final r0 = r * (0.6 + 0.7 * t) * reach;
      final r1 = r0 + r * 0.44 * fade * reach;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r0, c + Offset(math.cos(a), math.sin(a)) * r1, paint);
    }
    canvas.drawCircle(
      c,
      r * (0.6 + reach * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.6 * fade),
    );
  }

  @override
  bool shouldRepaint(BurstPainter old) => old.t != t || old.color != color;
}
