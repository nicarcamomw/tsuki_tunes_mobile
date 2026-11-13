part of '../expanded_player_screen.dart';

class _TitleMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TitleMarquee({required this.text, required this.style});

  @override
  State<_TitleMarquee> createState() => _TitleMarqueeState();
}

class _TitleMarqueeState extends State<_TitleMarquee> {
  late final ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
  }

  @override
  void didUpdateWidget(_TitleMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _isScrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startMarqueeLoop() async {
    if (!mounted || _isScrolling) return;
    _isScrolling = true;

    while (mounted && _isScrolling) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      final duration = Duration(
        milliseconds: (maxScroll * 40).clamp(1200, 6000).toInt(),
      );
      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );

      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted || !_isScrolling || !_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}

class _IsolatedProgressBar extends ConsumerWidget {
  const _IsolatedProgressBar({required this.locale});

  final LocaleProvider locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AudioProgressSelector<(Duration, Duration, Duration)>(
      selector: (a) => (a.position, a.duration, a.bufferedPosition),
      builder: (context, p) => _ScrubBar(locale: locale, position: p.$1, duration: p.$2, buffered: p.$3),
    );
  }
}

/// R-07: the progress bar grows under the finger and a bubble over the
/// thumb shows the time it will jump to.
class _ScrubBar extends StatefulWidget {
  const _ScrubBar({required this.locale, required this.position, required this.duration, required this.buffered});

  final LocaleProvider locale;
  final Duration position;
  final Duration duration;
  final Duration buffered;

  @override
  State<_ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<_ScrubBar> {
  ThumbDragDetails? _drag;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final drag = _drag;
    final dragging = drag != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProgressBar(
            progress: widget.position,
            total: widget.duration,
            buffered: widget.buffered,
            onSeek: context.readState(audioProvider).seek,
            onDragStart: (d) => setState(() => _drag = d),
            onDragUpdate: (d) => setState(() => _drag = d),
            onDragEnd: () => setState(() => _drag = null),
            progressBarColor: PlayerTint.of(context),
            baseBarColor: AppColors.border,
            bufferedBarColor: AppColors.borderGlow,
            thumbColor: PlayerTint.of(context),
            thumbGlowColor: PlayerTint.glowOf(context),
            barHeight: dragging ? 9 : 5,
            thumbRadius: dragging ? 10 : 7,
            timeLabelTextStyle: locale.getTextStyle(
              fontSize: AppFontSize.caption,
              color: AppColors.textSecondary,
            ),
          ),
          if (drag != null)
            Positioned(
              left: drag.localPosition.dx - 28,
              top: -34,
              child: IgnorePointer(
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: PlayerTint.of(context).withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    Formatters.formatDuration(drag.timeStamp),
                    style: locale.getTextStyle(
                      fontSize: AppFontSize.caption,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingGlowPlay extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  const _PulsingGlowPlay({required this.isPlaying, required this.isBuffering});

  @override
  State<_PulsingGlowPlay> createState() => _PulsingGlowPlayState();
}

class _PulsingGlowPlayState extends State<_PulsingGlowPlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncGlow();
  }

  // The glow breathes while playing, unless less motion was asked for.
  void _syncGlow() {
    if (widget.isPlaying && !reduceMotion(context)) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else if (_glow.isAnimating) {
      _glow.stop();
      _glow.value = widget.isPlaying ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingGlowPlay old) {
    super.didUpdateWidget(old);
    if (reduceMotion(context)) {
      _glow.value = widget.isPlaying ? 1 : 0;
    } else if (widget.isPlaying && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!widget.isPlaying && _glow.isAnimating) {
      _glow.animateTo(0.0, duration: AppMotion.normal);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PlayerTint.of(context),
          boxShadow: [
            BoxShadow(
              color: PlayerTint.glowOf(context),
              blurRadius: 18 + 12 * _glow.value,
              spreadRadius: 2 + 4 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
      child: Center(
        child: widget.isBuffering
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.textBright),
                ),
              )
            : Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: AppColors.textBright,
              ),
      ),
    );
  }
}
